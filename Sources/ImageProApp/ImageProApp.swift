import AppKit
import ImageProCore
import SwiftUI

@MainActor
final class OpenFileCoordinator: ObservableObject {
    static let shared = OpenFileCoordinator()
    @Published var pendingURL: URL?

    func receive(_ url: URL) {
        pendingURL = url
    }
}

final class ImageProAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.servicesProvider = self
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        OpenFileCoordinator.shared.receive(URL(fileURLWithPath: filename))
        sender.reply(toOpenOrPrint: .success)
    }

    @objc func autoRemoveBackground(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        do {
            let input = try serviceInputURL(from: pasteboard)
            let data = try Data(contentsOf: input)
            let decoded = try ImageIOService.decode(data: data)
            let cutout = try BackgroundRemovalService(
                provider: VisionForegroundSegmenter()
            ).removeBackground(from: decoded.image)
            let outputData = try ImageEncoderService.encode(
                image: cutout,
                format: .png,
                quality: 1,
                sourceProperties: decoded.sourceProperties,
                metadataPolicy: .removePrivate
            )
            let desired = input.deletingLastPathComponent().appendingPathComponent(
                input.deletingPathExtension().lastPathComponent + "-remove-bg.png"
            )
            guard let output = OutputURLResolver.resolve(desired, policy: .uniqueName) else {
                throw ImageProcessingError.encodeFailed
            }
            try outputData.write(to: output, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch let serviceError {
            error.pointee = serviceError.localizedDescription as NSString
        }
    }

    @objc func optimizeImage(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        do {
            let input = try serviceInputURL(from: pasteboard)
            let result = try SmartOptimizer().optimize(
                data: Data(contentsOf: input),
                parameters: OptimizeParameters.parameters(for: .balanced)
            )
            let desired = input.deletingLastPathComponent().appendingPathComponent(
                input.deletingPathExtension().lastPathComponent + "-optimized.\(result.format.fileExtension)"
            )
            guard let output = OutputURLResolver.resolve(desired, policy: .uniqueName) else {
                throw ImageProcessingError.encodeFailed
            }
            try result.data.write(to: output, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch let serviceError {
            error.pointee = serviceError.localizedDescription as NSString
        }
    }

    private func serviceInputURL(from pasteboard: NSPasteboard) throws -> URL {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
            let url = urls.first
        else { throw ImageProcessingError.invalidImage }
        return url
    }
}

@MainActor
private enum AboutPanelPresenter {
    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 4
        let credits = NSAttributedString(
            string: "Built out of laziness\nAttapon Mongkon",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        )
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.3.0"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Image Pro",
            .applicationVersion: version,
            .version: "",
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ImageProApp: App {
    @NSApplicationDelegateAdaptor(ImageProAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var openFileCoordinator = OpenFileCoordinator.shared
    @StateObject private var updateController = UpdateController()
    @StateObject private var modelManager = ModelManagerController()
    @StateObject private var settingsNavigation = SettingsNavigationController()
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.english.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .english
    }

    private var isBusy: Bool {
        model.isWorking || model.isBatchRunning
    }

    var body: some Scene {
        Window("Image Pro", id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(openFileCoordinator)
                .environmentObject(updateController)
                .environmentObject(modelManager)
                .environmentObject(settingsNavigation)
                .environment(\.locale, appLanguage.locale)
                .frame(minWidth: 1_180, minHeight: 720)
                .task { updateController.checkAutomaticallyIfNeeded() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_240, height: 780)
        .environment(\.locale, appLanguage.locale)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Image Pro") {
                    AboutPanelPresenter.show()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open Image…") {
                    model.chooseImage()
                }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(isBusy)
                Button("Open Project…") { model.chooseProject() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(isBusy)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!model.canUndo || isBusy)
                Button("Redo") { model.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canRedo || isBusy)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Project") { model.saveProject() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(model.activeData == nil || isBusy)
                Button("Save Project As…") { model.saveProjectAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(model.activeData == nil || isBusy)
                Button("Export Current Image…") { model.exportDefault() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(model.activeData == nil || isBusy)
            }
            CommandGroup(after: .pasteboard) {
                Button("Paste Image") { model.pasteImageFromClipboard() }
                    .keyboardShortcut("v", modifiers: [.command, .option])
                    .disabled(isBusy)
                Button("Copy Current Image") { model.copyCurrentImage() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(model.activeData == nil || isBusy)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updateController.checkForUpdates()
                }
                .disabled(updateController.isChecking || updateController.isInstalling)
            }
            CommandMenu("Tools") {
                Button("Optimize") { model.selectedTool = .optimize }
                    .keyboardShortcut("1", modifiers: .option)
                    .disabled(isBusy)
                Button("Remove Background") { model.selectedTool = .removeBackground }
                    .keyboardShortcut("2", modifiers: .option)
                    .disabled(isBusy)
                Button("Crop & Resize") { model.selectedTool = .cropResize }
                    .keyboardShortcut("3", modifiers: .option)
                    .disabled(isBusy)
                Button("Upscale") { model.selectedTool = .upscale }
                    .keyboardShortcut("4", modifiers: .option)
                    .disabled(isBusy)
                Button("Erase") { model.selectedTool = .erase }
                    .keyboardShortcut("5", modifiers: .option)
                    .disabled(isBusy)
                Button("Generate") { model.selectedTool = .generate }
                    .keyboardShortcut("6", modifiers: .option)
                    .disabled(isBusy)
                Button("OCR") { model.selectedTool = .ocr }
                    .keyboardShortcut("7", modifiers: .option)
                    .disabled(isBusy)
                Divider()
                Button("Run OCR") {
                    model.selectedTool = .ocr
                    model.recognizeText()
                }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(model.activeData == nil || isBusy)
            }
            CommandMenu("View") {
                Button("Zoom In") { model.adjustZoom(by: 1.25) }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(isBusy)
                Button("Zoom Out") { model.adjustZoom(by: 0.8) }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(isBusy)
                Button("Fit Image") { model.resetCanvasView() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(isBusy)
                Button(model.isPanMode ? "Disable Pan Mode" : "Enable Pan Mode") {
                    model.isPanMode.toggle()
                }
                    .keyboardShortcut("h", modifiers: .command)
                    .disabled(isBusy)
            }
        }

        Settings {
            AppSettingsView()
                .environmentObject(updateController)
                .environmentObject(modelManager)
                .environmentObject(settingsNavigation)
                .environment(\.locale, appLanguage.locale)
        }
        .windowResizability(.contentSize)
    }
}
