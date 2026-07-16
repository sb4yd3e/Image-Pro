import AppKit
import ImageProCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var openFileCoordinator: OpenFileCoordinator
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopToolbar()
                HStack(spacing: 10) {
                    Sidebar()
                        .frame(width: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    CanvasView(isDropTargeted: isDropTargeted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Inspector()
                        .frame(width: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                StatusBar()
            }
            .allowsHitTesting(!isBusy)

            if isBusy {
                ProcessingBlocker(isBatch: model.isBatchRunning)
                    .environmentObject(model)
                    .transition(.opacity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            guard !model.isWorking, !model.isBatchRunning else { return false }
            guard let provider = providers.first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard
                    let data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                Task { @MainActor in model.openDocument(url) }
            }
            return true
        }
        .alert("Image Pro", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .onReceive(openFileCoordinator.$pendingURL.compactMap { $0 }) { url in
            model.openDocument(url)
        }
        .onOpenURL { url in
            model.openDocument(url)
        }
    }

    private var isBusy: Bool {
        model.isWorking || model.isBatchRunning
    }
}

private struct ProcessingBlocker: View {
    @EnvironmentObject private var model: AppModel
    let isBatch: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(isBatch ? "Processing batch…" : model.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Button("Cancel", role: .cancel) {
                    if isBatch {
                        model.cancelBatch()
                    } else {
                        model.cancelCurrentOperation()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 18)
        }
    }
}

private struct TopToolbar: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settingsNavigation: SettingsNavigationController
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.english.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        HStack(spacing: 10) {
            Button("Open", systemImage: "folder") { model.chooseImage() }
                .disabled(model.isWorking)
                .accessibilityLabel("Open Image")
            Menu("Project", systemImage: "shippingbox") {
                Button("Open Project…", systemImage: "folder") { model.chooseProject() }
                Button("Save Project", systemImage: "square.and.arrow.down") { model.saveProject() }
                    .disabled(model.activeData == nil)
                Button("Save Project As…", systemImage: "doc.badge.plus") { model.saveProjectAs() }
                    .disabled(model.activeData == nil)
            }
            Button(action: { model.pasteImageFromClipboard() }) { Image(systemName: "doc.on.clipboard") }
                .help("Paste image from clipboard")
                .disabled(model.isWorking)
                .accessibilityLabel("Paste Image from Clipboard")
            Button(action: { model.copyCurrentImage() }) { Image(systemName: "doc.on.doc") }
                .help("Copy current image")
                .disabled(model.activeData == nil || model.isWorking)
                .accessibilityLabel("Copy Current Image")
            Button(action: { model.undo() }) { Image(systemName: "arrow.uturn.backward") }
                .help("Undo")
                .disabled(!model.canUndo || model.isWorking)
                .accessibilityLabel("Undo")
            Button(action: { model.redo() }) { Image(systemName: "arrow.uturn.forward") }
                .help("Redo")
                .disabled(!model.canRedo || model.isWorking)
                .accessibilityLabel("Redo")
            Button("Revert", systemImage: "arrow.counterclockwise") { model.resetToOriginal() }
                .disabled(!model.hasAppliedEdit || model.isWorking)
            Button("Export…", systemImage: "square.and.arrow.up") { model.exportDefault() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("e", modifiers: .command)
                .help("Export the current result. Choose Optimize for format and quality controls.")
                .disabled(model.activeData == nil || model.isWorking)
                .accessibilityLabel("Export Image")
            WindowTitleDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Picker("Compare", selection: $model.comparisonMode) {
                ForEach(AppModel.ComparisonMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
            Menu {
                Button("English") {
                    languageRawValue = AppLanguage.english.rawValue
                }
                .disabled(appLanguage == .english)
                Button("Thai") {
                    languageRawValue = AppLanguage.thai.rawValue
                }
                .disabled(appLanguage == .thai)
                Divider()
                Button {
                    settingsNavigation.showGeneral()
                    openSettings()
                } label: {
                    Label("Language & Appearance", systemImage: "gearshape")
                }
            } label: {
                Label(appLanguage.shortTitle, systemImage: "globe")
                    .frame(minWidth: 42)
            }
            .menuStyle(.button)
            .help("App Language")
            if model.isWorking {
                ProgressView().controlSize(.small)
                Button("Cancel", role: .cancel) { model.cancelCurrentOperation() }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .frame(height: 60)
    }
}

/// A native title-bar region that preserves normal macOS window behavior without
/// placing an invisible gesture over toolbar controls. Dragging moves the window;
/// double-clicking zooms/maximizes it just like a standard title bar.
private struct WindowTitleDragRegion<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            WindowTitleDragView()
            content()
                .allowsHitTesting(false)
        }
    }
}

private extension WindowTitleDragRegion where Content == Color {
    init() {
        self.init { Color.clear }
    }
}

private struct WindowTitleDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TitleDragNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class TitleDragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                window.performZoom(nil)
            } else {
                window.performDrag(with: event)
            }
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Library", systemImage: "rectangle.stack")
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            Button {
                model.selectedTool = .batchQueue
                model.isPanMode = false
            } label: {
                Label("Batch Queue", systemImage: "clock")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .background(
                        model.selectedTool == .batchQueue
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Batch Queue")
            if !model.recentFiles.isEmpty {
                HStack {
                    Text("RECENT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { model.clearRecentFiles() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .disabled(model.isWorking)
                        .help("Clear recent file history. Files are not deleted.")
                        .accessibilityLabel("Clear Recent Files")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                ForEach(model.recentFiles.prefix(3), id: \.self) { url in
                    Button {
                        model.open(url)
                    } label: {
                        Label(url.deletingPathExtension().lastPathComponent, systemImage: "photo")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(url.path)
                    .disabled(model.isWorking)
                    .accessibilityLabel("Open recent image \(url.lastPathComponent)")
                }
            }
            Divider().padding(.vertical, 6)
            ForEach(AppModel.Tool.allCases.filter { $0 != .batchQueue }) { tool in
                Button {
                    model.selectedTool = tool
                    model.isPanMode = false
                    if (tool == .erase || tool == .generate), !model.maskDocument.hasPaintedContent {
                        model.brushPaintsMask = true
                    }
                    if tool == .removeBackground || tool == .cropResize || tool == .erase || tool == .generate {
                        model.comparisonMode = .after
                    }
                } label: {
                    Label(LocalizedStringKey(tool.rawValue), systemImage: tool.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                        .background(
                            model.selectedTool == tool
                                ? Color.accentColor.opacity(0.18)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey(tool.rawValue)))
            }
            Spacer()
        }
        .padding(14)
        .background(.thinMaterial)
    }
}

private struct CanvasView: View {
    @EnvironmentObject private var model: AppModel
    let isDropTargeted: Bool
    @State private var draftMaskPoints: [MaskPoint] = []
    @State private var panAtGestureStart: CGSize?
    @State private var zoomAtGestureStart: Double?

    var body: some View {
        ZStack {
            Checkerboard()
            if
                model.comparisonMode == .split,
                let before = model.sourcePreviewImage,
                let after = model.image
            {
                ComparisonSplitView(
                    before: before,
                    after: after,
                    fraction: $model.comparisonFraction,
                    zoomScale: model.zoomScale,
                    panOffset: model.panOffset
                )
                .padding(24)
            } else if let image = model.displayImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
                    .scaleEffect(model.zoomScale)
                    .offset(model.panOffset)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 44, weight: .light))
                    Text("Drop an image here")
                        .font(.title2.weight(.medium))
                    Text("JPEG, PNG, HEIC, TIFF or WebP")
                        .foregroundStyle(.secondary)
                    Button("Choose Image…") { model.chooseImage() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                }
                .padding(36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(12)
            }
        }
        .overlay {
            GeometryReader { geometry in
                let imageRect = transformedImageRect(
                    canvasSize: geometry.size,
                    imageSize: model.sourceSize
                )
                if
                    model.isPanMode,
                    model.image != nil
                {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(panGesture)
                } else if
                    model.selectedTool == .removeBackground,
                    let backgroundMask = model.backgroundMaskPreviewImage,
                    model.image != nil
                {
                    Image(nsImage: backgroundMask)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .opacity(0.48)
                        .position(x: imageRect.midX, y: imageRect.midY)
                        .allowsHitTesting(false)
                    MaskOverlay(
                        document: model.backgroundRefineDocument,
                        draftPoints: draftMaskPoints,
                        draftDiameter: model.brushDiameter,
                        draftPaintsMask: model.backgroundBrushKeepsMask,
                        imageRect: imageRect,
                        paintColor: .green.opacity(0.62),
                        refineColor: .red.opacity(0.62)
                    )
                    .contentShape(Rectangle())
                    .gesture(backgroundMaskGesture(imageRect: imageRect))
                } else if
                    isMaskTool,
                    model.image != nil
                {
                    MaskOverlay(
                        document: model.maskDocument,
                        draftPoints: draftMaskPoints,
                        draftDiameter: model.brushDiameter,
                        draftPaintsMask: model.brushPaintsMask,
                        imageRect: imageRect
                    )
                    .contentShape(Rectangle())
                    .gesture(maskGesture(imageRect: imageRect))
                } else if
                    model.selectedTool == .ocr,
                    !model.ocrBlocks.isEmpty,
                    model.image != nil
                {
                    OCRBoundingBoxesOverlay(blocks: model.ocrBlocks, imageRect: imageRect)
                        .allowsHitTesting(false)
                } else if
                    model.selectedTool == .cropResize,
                    let imageSize = model.sourceSize,
                    model.image != nil
                {
                    CropSelectionOverlay(
                        selection: $model.cropSelection,
                        aspectRatio: model.cropAspectRatio,
                        imageAspectRatio: imageSize.aspectRatio,
                        imageRect: imageRect
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(magnifyGesture)
        .clipped()
    }

    private var isMaskTool: Bool {
        model.generatedVariants.isEmpty
            && (model.selectedTool == .erase
                || (model.selectedTool == .generate && !model.isOutpaintMode))
    }

    private func maskGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let point = normalizedPoint(value.location, in: imageRect) else { return }
                if let last = draftMaskPoints.last {
                    let distance = hypot(point.x - last.x, point.y - last.y)
                    if distance < 0.002 { return }
                }
                draftMaskPoints.append(point)
            }
            .onEnded { _ in
                model.appendMaskStroke(points: draftMaskPoints)
                draftMaskPoints = []
            }
    }

    private func backgroundMaskGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let point = normalizedPoint(value.location, in: imageRect) else { return }
                if let last = draftMaskPoints.last, hypot(point.x - last.x, point.y - last.y) < 0.002 {
                    return
                }
                draftMaskPoints.append(point)
            }
            .onEnded { _ in
                model.appendBackgroundRefineStroke(points: draftMaskPoints)
                draftMaskPoints = []
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if panAtGestureStart == nil { panAtGestureStart = model.panOffset }
                let start = panAtGestureStart ?? .zero
                model.updatePan(CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                ))
            }
            .onEnded { _ in panAtGestureStart = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomAtGestureStart == nil { zoomAtGestureStart = model.zoomScale }
                model.setZoom((zoomAtGestureStart ?? 1) * Double(value))
            }
            .onEnded { _ in
                zoomAtGestureStart = nil
            }
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> MaskPoint? {
        guard rect.contains(point), rect.width > 0, rect.height > 0 else { return nil }
        return MaskPoint(
            x: Double((point.x - rect.minX) / rect.width),
            y: Double((point.y - rect.minY) / rect.height)
        )
    }

    private func fittedImageRect(canvasSize: CGSize, imageSize: PixelSize) -> CGRect {
        let available = CGSize(
            width: max(1, canvasSize.width - 48),
            height: max(1, canvasSize.height - 48)
        )
        let scale = min(
            available.width / CGFloat(imageSize.width),
            available.height / CGFloat(imageSize.height)
        )
        let size = CGSize(
            width: CGFloat(imageSize.width) * scale,
            height: CGFloat(imageSize.height) * scale
        )
        return CGRect(
            x: (canvasSize.width - size.width) / 2,
            y: (canvasSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func transformedImageRect(canvasSize: CGSize, imageSize: PixelSize?) -> CGRect {
        guard let imageSize else { return .zero }
        let base = fittedImageRect(canvasSize: canvasSize, imageSize: imageSize)
        let width = base.width * model.zoomScale
        let height = base.height * model.zoomScale
        return CGRect(
            x: canvasSize.width / 2 - width / 2 + model.panOffset.width,
            y: canvasSize.height / 2 - height / 2 + model.panOffset.height,
            width: width,
            height: height
        )
    }
}

private struct ComparisonSplitView: View {
    let before: NSImage
    let after: NSImage
    @Binding var fraction: Double
    let zoomScale: Double
    let panOffset: CGSize

    var body: some View {
        GeometryReader { geometry in
            let baseRect = fittedRect(in: geometry.size)
            let rect = transformedRect(baseRect, in: geometry.size)
            ZStack(alignment: .topLeading) {
                ZStack {
                    Image(nsImage: after)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: rect.width, height: rect.height)
                    Image(nsImage: before)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: rect.width, height: rect.height)
                        .clipped()
                        .mask(SplitRevealShape(fraction: fraction))
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2, height: rect.height)
                    .shadow(radius: 2)
                    .position(x: rect.minX + rect.width * fraction, y: rect.midY)

                HStack {
                    Text("BEFORE")
                    Spacer()
                    Text("AFTER")
                }
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(8)
                .frame(width: rect.width)
                .position(x: rect.midX, y: rect.minY + 16)
            }
            .contentShape(Path(rect))
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard rect.contains(value.location) else { return }
                    fraction = min(max(Double((value.location.x - rect.minX) / max(1, rect.width)), 0.02), 0.98)
                }
            )
        }
    }

    private func fittedRect(in available: CGSize) -> CGRect {
        let size = after.pixelSize
        let scale = min(available.width / size.width, available.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: (available.width - fitted.width) / 2,
            y: (available.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func transformedRect(_ rect: CGRect, in available: CGSize) -> CGRect {
        let width = rect.width * zoomScale
        let height = rect.height * zoomScale
        return CGRect(
            x: available.width / 2 - width / 2 + panOffset.width,
            y: available.height / 2 - height / 2 + panOffset.height,
            width: width,
            height: height
        )
    }
}

private extension NSImage {
    var pixelSize: CGSize {
        if let representation = representations.first, representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }
}

private struct SplitRevealShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height))
    }
}

private struct CropSelectionOverlay: View {
    @Binding var selection: CGRect
    let aspectRatio: Double?
    let imageAspectRatio: Double
    let imageRect: CGRect

    @State private var dragStart: CGPoint?
    @State private var initialSelection: CGRect?
    @State private var dragMode = DragMode.new

    private enum DragMode {
        case new, move, topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        Canvas { context, size in
            let cropRect = canvasRect(selection)
            var shade = Path(CGRect(origin: .zero, size: size))
            shade.addRect(cropRect)
            context.fill(shade, with: .color(.black.opacity(0.52)), style: FillStyle(eoFill: true))
            context.stroke(Path(cropRect), with: .color(.white), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))

            for point in cornerPoints(cropRect) {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
                    with: .color(.white)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
                    with: .color(.accentColor),
                    lineWidth: 2
                )
            }
        }
        .contentShape(Rectangle())
        .gesture(cropGesture)
        .overlay(alignment: .topLeading) {
            Text("Drag inside to move • Drag corners to resize • Drag outside to draw")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(.white)
                .background(.black.opacity(0.65), in: Capsule())
                .position(x: imageRect.midX, y: max(14, imageRect.minY - 14))
        }
    }

    private var cropGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard imageRect.contains(value.startLocation) else { return }
                let current = normalized(value.location)
                if dragStart == nil {
                    let start = normalized(value.startLocation)
                    dragStart = start
                    initialSelection = selection
                    dragMode = mode(at: value.startLocation)
                }
                guard let start = dragStart, let initial = initialSelection else { return }
                selection = updatedSelection(start: start, current: current, initial: initial, mode: dragMode)
            }
            .onEnded { _ in
                dragStart = nil
                initialSelection = nil
            }
    }

    private func mode(at point: CGPoint) -> DragMode {
        let rect = canvasRect(selection)
        if selection.width > 0.98, selection.height > 0.98 {
            return .new
        }
        let threshold: CGFloat = 18
        let corners: [(CGPoint, DragMode)] = [
            (CGPoint(x: rect.minX, y: rect.minY), .topLeft),
            (CGPoint(x: rect.maxX, y: rect.minY), .topRight),
            (CGPoint(x: rect.minX, y: rect.maxY), .bottomLeft),
            (CGPoint(x: rect.maxX, y: rect.maxY), .bottomRight)
        ]
        if let hit = corners.first(where: { hypot($0.0.x - point.x, $0.0.y - point.y) <= threshold }) {
            return hit.1
        }
        return rect.contains(point) ? .move : .new
    }

    private func updatedSelection(
        start: CGPoint,
        current: CGPoint,
        initial: CGRect,
        mode: DragMode
    ) -> CGRect {
        switch mode {
        case .move:
            let dx = current.x - start.x
            let dy = current.y - start.y
            return CGRect(
                x: min(max(initial.minX + dx, 0), 1 - initial.width),
                y: min(max(initial.minY + dy, 0), 1 - initial.height),
                width: initial.width,
                height: initial.height
            )
        case .new:
            return rect(from: start, to: current)
        case .topLeft:
            return rect(from: current, to: CGPoint(x: initial.maxX, y: initial.maxY))
        case .topRight:
            return rect(from: CGPoint(x: initial.minX, y: current.y), to: CGPoint(x: current.x, y: initial.maxY))
        case .bottomLeft:
            return rect(from: CGPoint(x: current.x, y: initial.minY), to: CGPoint(x: initial.maxX, y: current.y))
        case .bottomRight:
            return rect(from: CGPoint(x: initial.minX, y: initial.minY), to: current)
        }
    }

    private func rect(from first: CGPoint, to second: CGPoint) -> CGRect {
        let x = min(first.x, second.x)
        let y = min(first.y, second.y)
        var width = max(0.02, abs(second.x - first.x))
        var height = max(0.02, abs(second.y - first.y))
        if let aspectRatio {
            let normalizedRatio = aspectRatio / max(0.0001, imageAspectRatio)
            if width / height > normalizedRatio {
                width = height * normalizedRatio
            } else {
                height = width / normalizedRatio
            }
        }
        width = min(width, 1 - x)
        height = min(height, 1 - y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func normalized(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max((point.x - imageRect.minX) / max(1, imageRect.width), 0), 1),
            y: min(max((point.y - imageRect.minY) / max(1, imageRect.height), 0), 1)
        )
    }

    private func canvasRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + rect.minX * imageRect.width,
            y: imageRect.minY + rect.minY * imageRect.height,
            width: rect.width * imageRect.width,
            height: rect.height * imageRect.height
        )
    }

    private func cornerPoints(_ rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }
}

private struct MaskOverlay: View {
    let document: MaskDocument
    let draftPoints: [MaskPoint]
    let draftDiameter: Double
    let draftPaintsMask: Bool
    let imageRect: CGRect
    var paintColor = Color.red.opacity(0.52)
    var refineColor = Color.cyan.opacity(0.6)

    var body: some View {
        Canvas { context, _ in
            for stroke in document.strokes {
                draw(
                    points: stroke.points,
                    diameter: stroke.diameter,
                    paintsMask: stroke.paintsMask,
                    context: &context
                )
            }
            draw(
                points: draftPoints,
                diameter: draftDiameter,
                paintsMask: draftPaintsMask,
                context: &context
            )
        }
        .allowsHitTesting(true)
    }

    private func draw(
        points: [MaskPoint],
        diameter: Double,
        paintsMask: Bool,
        context: inout GraphicsContext
    ) {
        guard let first = points.first else { return }
        let color = paintsMask ? paintColor : refineColor
        let lineWidth = CGFloat(diameter) * min(imageRect.width, imageRect.height)
        if points.count == 1 {
            let center = canvasPoint(first)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - lineWidth / 2,
                    y: center.y - lineWidth / 2,
                    width: lineWidth,
                    height: lineWidth
                )),
                with: .color(color)
            )
            return
        }
        var path = Path()
        path.move(to: canvasPoint(first))
        for point in points.dropFirst() {
            path.addLine(to: canvasPoint(point))
        }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func canvasPoint(_ point: MaskPoint) -> CGPoint {
        CGPoint(
            x: imageRect.minX + CGFloat(point.x) * imageRect.width,
            y: imageRect.minY + CGFloat(point.y) * imageRect.height
        )
    }
}

private struct OCRBoundingBoxesOverlay: View {
    let blocks: [OCRTextBlock]
    let imageRect: CGRect

    var body: some View {
        Canvas { context, _ in
            for block in blocks {
                let box = block.boundingBox
                let rect = CGRect(
                    x: imageRect.minX + box.minX * imageRect.width,
                    y: imageRect.minY + (1 - box.maxY) * imageRect.height,
                    width: box.width * imageRect.width,
                    height: box.height * imageRect.height
                )
                context.stroke(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color(.yellow.opacity(0.95)),
                    lineWidth: 2
                )
                context.fill(Path(rect), with: .color(.yellow.opacity(0.08)))
            }
        }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 16
            let rows = Int(ceil(size.height / cell))
            let columns = Int(ceil(size.width / cell))
            for row in 0..<rows {
                for column in 0..<columns {
                    let color = (row + column).isMultiple(of: 2)
                        ? Color(nsColor: .underPageBackgroundColor)
                        : Color(nsColor: .separatorColor).opacity(0.3)
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

private struct Inspector: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.selectedTool {
            case .batchQueue:
                BatchInspector()
            case .optimize:
                OptimizeInspector()
            case .removeBackground:
                RemoveBackgroundInspector()
            case .cropResize:
                CropResizeInspector()
            case .upscale:
                UpscaleInspector()
            case .erase:
                EraseInspector()
            case .generate:
                GenerateInspector()
            case .ocr:
                OCRInspector()
            }
        }
        .padding(20)
        .background(.thinMaterial)
    }
}

private struct OCRInspector: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Offline OCR", systemImage: "text.viewfinder")
                    .font(.title2.bold())
                Text("Recognize printed or handwritten text locally with Apple Vision. Available languages depend on this macOS version.")
                    .foregroundStyle(.secondary)

                Picker("Quality", selection: $model.ocrQuality) {
                    Text("Fast").tag(OCRRecognitionQuality.fast)
                    Text("Accurate").tag(OCRRecognitionQuality.accurate)
                }
                .pickerStyle(.segmented)
                .onChange(of: model.ocrQuality) { _, _ in model.loadOCRLanguages() }

                LabeledContent("Language") {
                    Picker("Language", selection: $model.ocrLanguage) {
                        Text("Auto Detect").tag("")
                        ForEach(model.ocrSupportedLanguages, id: \.self) { language in
                            Text(languageName(language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 165)
                }
                Toggle("Language correction", isOn: $model.ocrUsesLanguageCorrection)
                    .accessibilityLabel("Language Correction")
                Text("\(model.ocrSupportedLanguages.count) language configurations available on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    model.recognizeText()
                } label: {
                    Label("Recognize Text", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.activeData == nil || model.isWorking)
                .accessibilityLabel("Recognize Text")

                if !model.ocrText.isEmpty {
                    HStack {
                        Text("Result").font(.headline)
                        Spacer()
                        if !model.ocrBlocks.isEmpty {
                            Text("\(model.ocrBlocks.count) lines")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    TextEditor(text: $model.ocrText)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                        .padding(4)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Recognized Text")
                    HStack {
                        Button("Copy Text", systemImage: "doc.on.doc") { model.copyOCRText() }
                            .accessibilityLabel("Copy Recognized Text")
                        Button("Save TXT…", systemImage: "square.and.arrow.down") { model.exportOCRText() }
                            .accessibilityLabel("Save Recognized Text")
                    }
                } else {
                    ContentUnavailableView(
                        "No OCR Result",
                        systemImage: "text.magnifyingglass",
                        description: Text("Run recognition to extract editable text.")
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { model.loadOCRLanguages() }
    }

    private func languageName(_ identifier: String) -> String {
        let localized = locale.localizedString(forIdentifier: identifier) ?? identifier
        return "\(localized) (\(identifier))"
    }
}

private struct GenerateInspector: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var modelManager: ModelManagerController
    @State private var mode = GenerationMode.fill
    @State private var prompt = ""
    @State private var negativePrompt = ""
    @State private var seed: UInt32 = 1
    @State private var strength = 0.58
    @State private var steps = 12
    @State private var variantCount = 1
    @State private var outpaintDirection = OutpaintDirection.right
    @State private var outpaintFraction = 0.25
    @State private var generationPreset = GenerationPreset.balanced

    private enum GenerationMode: String, CaseIterable, Identifiable {
        case fill = "Fill Mask"
        case outpaint = "Outpaint"
        var id: String { rawValue }
    }

    private enum GenerationPreset: String, CaseIterable, Identifiable {
        case fast = "Fast"
        case balanced = "Balanced"
        case quality = "Quality"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Generative Fill", systemImage: "wand.and.stars")
                    .font(.title2.bold())
                Text("Paint a mask on the image, then describe what should appear inside it. Generation runs locally with Stable Diffusion.")
                    .foregroundStyle(.secondary)
                RequiredModelNotice(
                    capability: .generate,
                    engines: [.appleStableDiffusion],
                    available: hasGenerateModel
                )

                Picker("Mode", selection: $mode) {
                    ForEach(GenerationMode.allCases) { item in
                        Text(LocalizedStringKey(item.rawValue)).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Picker("AI quality", selection: $generationPreset) {
                    ForEach(GenerationPreset.allCases) { preset in
                        Text(LocalizedStringKey(preset.rawValue)).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: generationPreset) { _, preset in
                    switch preset {
                    case .fast:
                        steps = 8
                        strength = mode == .fill ? 0.48 : 0.72
                    case .balanced:
                        steps = 14
                        strength = mode == .fill ? 0.58 : 0.8
                    case .quality:
                        steps = 24
                        strength = mode == .fill ? 0.64 : 0.86
                    }
                }

                TextField("Describe the fill", text: $prompt, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                TextField("Negative prompt (optional)", text: $negativePrompt, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Seed") {
                    ImmediateIntegerField(
                        "Seed",
                        value: Binding(
                            get: { Int(seed) },
                            set: { seed = UInt32(clamping: $0) }
                        ),
                        range: 0...Int(UInt32.max)
                    )
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Creativity")
                        Spacer()
                        Text("\(Int(strength * 100))%").monospacedDigit()
                    }
                    Slider(value: $strength, in: 0.35...0.9)
                }
                Stepper("Steps: \(steps)", value: $steps, in: 8...35, step: 2)
                Stepper("Variants: \(variantCount)", value: $variantCount, in: 1...3)

                if mode == .fill {
                    Picker("Brush mode", selection: $model.brushPaintsMask) {
                        Text("Add Mask").tag(true)
                        Text("Subtract").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Slider(value: $model.brushDiameter, in: 0.01...0.3) {
                        Text("Brush size")
                    }
                    HStack {
                        Button("Undo Stroke") { model.undoMaskStroke() }
                            .disabled(model.maskDocument.isEmpty)
                        Button("Clear") { model.clearMask() }
                            .disabled(model.maskDocument.isEmpty)
                    }
                } else {
                    LabeledContent("Direction") {
                        Picker("Direction", selection: $outpaintDirection) {
                            ForEach(OutpaintDirection.allCases, id: \.self) { direction in
                                Text(LocalizedStringKey(direction.rawValue.capitalized)).tag(direction)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Expansion")
                            Spacer()
                            Text("\(Int(outpaintFraction * 100))%")
                                .monospacedDigit()
                        }
                        Slider(value: $outpaintFraction, in: 0.1...0.5, step: 0.05)
                    }
                }

                Label(
                    "Runs offline in a 512 px AI context. Quality mode uses more time and memory.",
                    systemImage: "memorychip"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if model.isWorking, model.generativeProgress > 0 {
                    ProgressView(value: model.generativeProgress)
                    Text("\(Int(model.generativeProgress * 100))%")
                        .font(.caption.monospacedDigit())
                }

                if !model.generatedVariants.isEmpty {
                    Text("Variants").font(.headline)
                    HStack {
                        ForEach(model.generatedVariants.indices, id: \.self) { index in
                            if let image = NSImage(data: model.generatedVariants[index]) {
                                Button {
                                    model.selectGeneratedVariant(index)
                                } label: {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 62, height: 62)
                                        .clipped()
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(
                                                    index == model.selectedVariantIndex ? Color.accentColor : .clear,
                                                    lineWidth: 3
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Button("Discard", role: .destructive) { model.discardGeneratedVariants() }
                        Button("Generate Again", systemImage: "arrow.clockwise") {
                            if mode == .fill {
                                model.generateMaskedFill(configuration: configuration)
                            } else {
                                model.generateOutpaint(
                                    configuration: configuration,
                                    direction: outpaintDirection,
                                    fraction: outpaintFraction
                                )
                            }
                        }
                        .disabled(model.isWorking)
                        Button("Apply") { model.applyGeneratedVariant() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWorking)
                    }
                } else {
                    Button {
                        if mode == .fill {
                            model.generateMaskedFill(configuration: configuration)
                        } else {
                            model.generateOutpaint(
                                configuration: configuration,
                                direction: outpaintDirection,
                                fraction: outpaintFraction
                            )
                        }
                    } label: {
                        Label(mode == .fill ? "Generate Fill" : "Generate Outpaint", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(
                        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || (mode == .fill && model.maskDocument.isEmpty)
                            || (mode == .fill && !model.maskDocument.hasPaintedContent)
                            || model.isWorking
                            || !hasGenerateModel
                    )
                }
            }
        }
        .onAppear { model.isOutpaintMode = mode == .outpaint }
        .onChange(of: mode) { _, value in
            model.isOutpaintMode = value == .outpaint
            strength = value == .outpaint ? 0.8 : 0.58
        }
    }

    private var configuration: GenerativeFillConfiguration {
        GenerativeFillConfiguration(
            prompt: prompt,
            negativePrompt: negativePrompt,
            seed: seed,
            strength: Float(strength),
            stepCount: steps,
            variantCount: variantCount
        )
    }

    private var hasGenerateModel: Bool {
        modelManager.hasActiveModel(for: .generate, engines: [.appleStableDiffusion])
    }
}

private struct UpscaleInspector: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var modelManager: ModelManagerController
    @State private var scale = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Upscale", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.title2.bold())
            Text("Real-ESRGAN enhances overlapping tiles locally through Core ML and combines them into a seamless image.")
                .foregroundStyle(.secondary)
            RequiredModelNotice(
                capability: .upscale,
                engines: [.coreML],
                available: hasUpscaleModel
            )
            Picker("Output scale", selection: $scale) {
                Text("2×").tag(2)
                Text("4×").tag(4)
            }
            .pickerStyle(.segmented)
            Label("Overlap tile processing", systemImage: "square.grid.3x3")
            if let size = model.sourceSize {
                Text("Next output: \(size.width * scale) × \(size.height * scale) px")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                let outputPixels = size.width * scale * size.height * scale
                if outputPixels > 80_000_000 {
                    Label(
                        "Large output may use significant memory. Try 2× first.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            if model.isWorking, model.upscaleProgress > 0 {
                ProgressView(value: model.upscaleProgress)
                Text("\(Int(model.upscaleProgress * 100))%")
                    .font(.caption.monospacedDigit())
            }
            Spacer()
            Button {
                model.upscaleWithRealESRGAN(scale: scale)
            } label: {
                Label("Upscale \(scale)×", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.activeData == nil || model.isWorking || !hasUpscaleModel)
        }
    }

    private var hasUpscaleModel: Bool {
        modelManager.hasActiveModel(for: .upscale, engines: [.coreML])
    }
}

private struct EraseInspector: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var modelManager: ModelManagerController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Erase Object", systemImage: "eraser")
                .font(.title2.bold())
            Text("Paint over the complete object and its shadow. Smart Erase expands the mask, rebuilds surrounding texture, and blends edges entirely offline.")
                .foregroundStyle(.secondary)
            RequiredModelNotice(
                capability: .erase,
                engines: [.coreML],
                available: hasEraseModel
            )
            Picker("Brush mode", selection: $model.brushPaintsMask) {
                Text("Add Mask").tag(true)
                Text("Subtract").tag(false)
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Brush size")
                    Spacer()
                    Text("\(Int(model.brushDiameter * 100))%")
                        .monospacedDigit()
                }
                Slider(value: $model.brushDiameter, in: 0.01...0.3)
            }
            HStack {
                Button("Undo Stroke", systemImage: "arrow.uturn.backward") {
                    model.undoMaskStroke()
                }
                .disabled(model.maskDocument.isEmpty)
                Button("Clear", role: .destructive) {
                    model.clearMask()
                }
                .disabled(model.maskDocument.isEmpty)
            }
            Label(
                model.maskDocument.isEmpty
                    ? "Draw on the image to create a mask"
                    : "\(model.maskDocument.strokes.count) stroke(s)",
                systemImage: "scribble"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.eraseMaskedArea()
            } label: {
                Label("Remove Object", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                model.activeData == nil || !model.maskDocument.hasPaintedContent ||
                    model.isWorking || !hasEraseModel
            )
        }
    }

    private var hasEraseModel: Bool {
        modelManager.hasActiveModel(for: .erase, engines: [.coreML])
    }
}

private struct RequiredModelNotice: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var settingsNavigation: SettingsNavigationController
    let capability: ModelCapability
    let engines: Set<ModelEngine>
    let available: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label {
                Text(LocalizedStringKey(available ? "Offline model ready" : "Model required"))
            } icon: {
                Image(systemName: available ? "checkmark.shield.fill" : "shippingbox")
            }
            .foregroundStyle(available ? Color.green : Color.orange)
            Spacer()
            if !available {
                Button {
                    settingsNavigation.showModels()
                    openSettings()
                } label: {
                    Text("Manage Models")
                }
                .controlSize(.small)
            }
        }
        .font(.callout)
        .padding(10)
        .background(
            (available ? Color.green : Color.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityLabel("\(capability.displayName) model \(available ? "ready" : "required")")
    }
}

private struct BatchInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var format: ImageFormat = .automatic
    @State private var quality = 0.82
    @State private var collisionPolicy: OutputCollisionPolicy = .uniqueName
    @State private var removePrivateMetadata = true
    @State private var autoRemoveBackground = false
    @State private var preserveFolderStructure = true
    @State private var resizeLongEdge = false
    @State private var longEdge = 1920

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Batch Queue", systemImage: "clock")
                    .font(.title2.bold())

                GroupBox("Input") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Add Images…", systemImage: "plus") {
                                model.chooseBatchImages()
                            }
                            Button("Add Folder…", systemImage: "folder.badge.plus") {
                                model.chooseBatchFolder()
                            }
                        }
                        .disabled(model.isBatchRunning)

                        if model.batchInputs.isEmpty {
                            Text("No images selected")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(model.batchInputs.count) images")
                                .font(.headline)
                            ForEach(model.batchInputs.prefix(5), id: \.self) { url in
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .font(.caption)
                            }
                            if model.batchInputs.count > 5 {
                                Text("+ \(model.batchInputs.count - 5) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox("Output") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Choose Folder…", systemImage: "folder") {
                            model.chooseBatchOutputDirectory()
                        }
                        .disabled(model.isBatchRunning)
                        Text(model.batchOutputDirectory?.path(percentEncoded: false) ?? "No output folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        LabeledContent("Format") {
                            Picker("Format", selection: $format) {
                                ForEach(availableFormats) { item in
                                    Text(LocalizedStringKey(item.displayName)).tag(item)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                        LabeledContent("Quality") {
                            Text("\(Int(quality * 100))")
                                .monospacedDigit()
                        }
                        Slider(value: $quality, in: 0.35...1)
                        Toggle("Remove private metadata", isOn: $removePrivateMetadata)
                            .accessibilityLabel("Remove Private Metadata")
                        Toggle("Preserve folder structure", isOn: $preserveFolderStructure)
                            .disabled(model.batchInputRoot == nil)
                            .accessibilityLabel("Preserve Folder Structure")
                        LabeledContent("Existing") {
                            Picker("Existing", selection: $collisionPolicy) {
                                Text("Unique name").tag(OutputCollisionPolicy.uniqueName)
                                Text("Replace").tag(OutputCollisionPolicy.replace)
                                Text("Skip").tag(OutputCollisionPolicy.skip)
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Recipe") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Auto Remove Background", isOn: $autoRemoveBackground)
                            .accessibilityLabel("Auto Remove Background")
                        Toggle("Resize long edge", isOn: $resizeLongEdge)
                            .accessibilityLabel("Resize Long Edge")
                        if resizeLongEdge {
                            LabeledContent("Long edge") {
                                ImmediateIntegerField("Pixels", value: $longEdge, range: 64...100_000)
                                    .frame(width: 90)
                                Text("px")
                            }
                        }
                        Text("Runs in order: Remove BG → Resize → Optimize → Export")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                if model.isBatchRunning {
                    ProgressView(
                        value: Double(model.batchCompletedCount),
                        total: Double(max(1, model.batchInputs.count))
                    )
                    Text("\(model.batchCompletedCount) of \(model.batchInputs.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !model.batchResults.isEmpty {
                    let succeeded = model.batchResults.filter(\.succeeded).count
                    let failed = model.batchResults.count - succeeded
                    GroupBox("Last Run") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(succeeded) completed", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                            if failed > 0 {
                                Label("\(failed) failed", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }
                }

                HStack {
                    Button("Clear") { model.clearBatch() }
                        .disabled(model.isBatchRunning || (model.batchInputs.isEmpty && model.batchResults.isEmpty))
                    Spacer()
                    if model.isBatchRunning {
                        Button("Cancel", role: .destructive) { model.cancelBatch() }
                    } else {
                        Button("Run Batch", systemImage: "play.fill") {
                            model.runBatch(
                                parameters: parameters,
                                collisionPolicy: collisionPolicy,
                                autoRemoveBackground: autoRemoveBackground,
                                preserveFolderStructure: preserveFolderStructure
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.batchInputs.isEmpty || model.batchOutputDirectory == nil)
                    }
                }
            }
        }
    }

    private var parameters: OptimizeParameters {
        OptimizeParameters(
            preset: .balanced,
            format: format,
            quality: quality,
            resize: resizeLongEdge ? .longEdge(max(64, longEdge)) : .keepOriginal,
            metadataPolicy: removePrivateMetadata ? .removePrivate : .keepAll
        )
    }

    private var availableFormats: [ImageFormat] {
        ImageFormat.allCases.filter(ImageEncoderService.supports)
    }
}

private struct CropResizeInspector: View {
    private enum CropPreset: String, CaseIterable, Identifiable {
        case free = "Free"
        case square = "1:1"
        case fourThree = "4:3"
        case sixteenNine = "16:9"

        var id: String { rawValue }

        var ratio: Double? {
            switch self {
            case .free: nil
            case .square: 1
            case .fourThree: 4.0 / 3.0
            case .sixteenNine: 16.0 / 9.0
            }
        }
    }

    @EnvironmentObject private var model: AppModel
    @State private var cropPreset: CropPreset = .free
    @State private var outputWidth = 1920
    @State private var outputHeight = 1080
    @State private var resizeMode: ResizeMode = .fit
    @State private var straightenAngle = 0.0
    @State private var lockAspectRatio = true
    @State private var isSynchronizingSize = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Crop & Resize", systemImage: "crop")
                    .font(.title2.bold())

                if let size = model.sourceSize {
                    Text("Current: \(size.width) × \(size.height) px")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                GroupBox("Crop") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Aspect", selection: $cropPreset) {
                            ForEach(CropPreset.allCases) { preset in
                                Text(LocalizedStringKey(preset.rawValue)).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        Label("Drag on the image to draw a crop. Drag inside to move it or drag a corner to resize.", systemImage: "cursorarrow.and.square.on.square.dashed")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let size = model.sourceSize {
                            let selection = model.cropSelection
                            let width = max(1, Int((Double(size.width) * selection.width).rounded()))
                            let height = max(1, Int((Double(size.height) * selection.height).rounded()))
                            HStack {
                                Text("Selection")
                                Spacer()
                                Text("\(width) × \(height) px")
                                    .monospacedDigit()
                            }
                            .font(.callout)
                        }

                        HStack {
                            Button("Reset") {
                                model.cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
                                cropPreset = .free
                            }
                            Spacer()
                            Button("Apply Crop", systemImage: "crop") {
                                model.applyCropSelection()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!cropIsValid || cropIsFullImage || model.activeData == nil || model.isWorking)
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Resize") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Width") {
                            ImmediateIntegerField("px", value: $outputWidth, range: 1...100_000)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                            Text("px")
                        }
                        LabeledContent("Height") {
                            ImmediateIntegerField("px", value: $outputHeight, range: 1...100_000)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                            Text("px")
                        }
                        Toggle("Lock aspect ratio", isOn: $lockAspectRatio)
                        HStack {
                            Button("Original") { resetResizeToCurrentSize() }
                            Button("50%") { setResizeScale(0.5) }
                            Button("Long Edge 1920") { setLongEdge(1920) }
                        }
                        .font(.caption)
                        LabeledContent("Mode") {
                            Picker("Mode", selection: $resizeMode) {
                                Text("Fit").tag(ResizeMode.fit)
                                Text("Fill").tag(ResizeMode.fill)
                                Text("Stretch").tag(ResizeMode.stretch)
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                        Button("Apply Resize", systemImage: "arrow.up.left.and.arrow.down.right") {
                            model.applyResize(width: outputWidth, height: outputHeight, mode: resizeMode)
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(outputWidth < 1 || outputHeight < 1 || model.activeData == nil || model.isWorking)
                    }
                    .padding(.top, 6)
                }

                GroupBox("Transform") {
                    VStack(spacing: 10) {
                        HStack {
                            TransformButton(symbol: "rotate.left", help: "Rotate left") { model.rotate(by: -90) }
                            TransformButton(symbol: "rotate.right", help: "Rotate right") { model.rotate(by: 90) }
                            TransformButton(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", help: "Flip horizontally") { model.flip(horizontal: true) }
                            TransformButton(symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down", help: "Flip vertically") { model.flip(horizontal: false) }
                        }
                        HStack {
                            Slider(value: $straightenAngle, in: -15...15, step: 0.1)
                            Text("\(straightenAngle, specifier: "%+.1f")°")
                                .frame(width: 52)
                                .monospacedDigit()
                        }
                        Button("Apply Straighten", systemImage: "align.horizontal.center") {
                            model.rotate(by: straightenAngle)
                            straightenAngle = 0
                        }
                        .disabled(abs(straightenAngle) < 0.05 || model.isWorking)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .onAppear { resetControlsToCurrentSize() }
        .onChange(of: model.sourceSize) { _, _ in resetControlsToCurrentSize() }
        .onChange(of: cropPreset) { _, _ in updateCropForPreset() }
        .onChange(of: outputWidth) { oldValue, newValue in
            guard lockAspectRatio, !isSynchronizingSize, oldValue != newValue, let size = model.sourceSize else { return }
            isSynchronizingSize = true
            outputHeight = max(1, Int((Double(newValue) / size.aspectRatio).rounded()))
            isSynchronizingSize = false
        }
        .onChange(of: outputHeight) { oldValue, newValue in
            guard lockAspectRatio, !isSynchronizingSize, oldValue != newValue, let size = model.sourceSize else { return }
            isSynchronizingSize = true
            outputWidth = max(1, Int((Double(newValue) * size.aspectRatio).rounded()))
            isSynchronizingSize = false
        }
    }

    private var cropIsValid: Bool {
        let crop = model.cropSelection
        return crop.minX >= 0 && crop.minY >= 0 && crop.width >= 0.02 && crop.height >= 0.02
            && crop.maxX <= 1.0001 && crop.maxY <= 1.0001
    }

    private var cropIsFullImage: Bool {
        let crop = model.cropSelection
        return abs(crop.minX) < 0.001 && abs(crop.minY) < 0.001
            && abs(crop.width - 1) < 0.001 && abs(crop.height - 1) < 0.001
    }

    private func resetControlsToCurrentSize() {
        guard let size = model.sourceSize else { return }
        outputWidth = size.width
        outputHeight = size.height
        cropPreset = .free
        model.cropAspectRatio = nil
        model.cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func updateCropForPreset() {
        model.cropAspectRatio = cropPreset.ratio
        guard let ratio = cropPreset.ratio, let size = model.sourceSize else {
            return
        }
        let sourceRatio = size.aspectRatio
        let width: Double
        let height: Double
        if sourceRatio > ratio {
            height = 1
            width = ratio / sourceRatio
        } else {
            width = 1
            height = sourceRatio / ratio
        }
        model.cropSelection = CGRect(
            x: (1 - width) / 2,
            y: (1 - height) / 2,
            width: width,
            height: height
        )
    }

    private func resetResizeToCurrentSize() {
        guard let size = model.sourceSize else { return }
        outputWidth = size.width
        outputHeight = size.height
    }

    private func setResizeScale(_ scale: Double) {
        guard let size = model.sourceSize else { return }
        outputWidth = max(1, Int(Double(size.width) * scale))
        outputHeight = max(1, Int(Double(size.height) * scale))
    }

    private func setLongEdge(_ longEdge: Int) {
        guard let size = model.sourceSize else { return }
        let fitted = size.constrainedTo(longEdge: longEdge)
        outputWidth = fitted.width
        outputHeight = fitted.height
    }
}

private struct ImmediateIntegerField: View {
    let prompt: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var text: String

    init(_ prompt: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.prompt = prompt
        _value = value
        self.range = range
        _text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        TextField(prompt, text: $text)
            .onChange(of: text) { _, newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: "")
                guard let parsed = Int(normalized) else { return }
                value = min(max(parsed, range.lowerBound), range.upperBound)
            }
            .onChange(of: value) { _, newValue in
                let current = Int(text.replacingOccurrences(of: ",", with: ""))
                if current != newValue { text = String(newValue) }
            }
    }
}

private struct TransformButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct OptimizeInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var preset: OptimizePreset = .balanced
    @State private var format: ImageFormat = .jpeg
    @State private var quality = 0.82
    @State private var removePrivateMetadata = true
    @State private var targetKilobytes = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimize").font(.title2.bold())
            LabeledContent("Preset") {
                Picker("Preset", selection: $preset) {
                    ForEach(OptimizePreset.allCases) { item in
                        Text(LocalizedStringKey(item.displayName)).tag(item)
                    }
                }
                .labelsHidden()
                .frame(width: 155)
            }
            LabeledContent("Format") {
                Picker("Format", selection: $format) {
                    ForEach(availableFormats) { item in
                        Text(LocalizedStringKey(item.displayName)).tag(item)
                    }
                }
                .labelsHidden()
                .frame(width: 155)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Quality")
                    Spacer()
                    Text("\(Int(quality * 100))")
                        .monospacedDigit()
                }
                Slider(value: $quality, in: 0.35...1)
            }
            if preset == .targetSize {
                LabeledContent("Target") {
                    ImmediateIntegerField("KB", value: $targetKilobytes, range: 1...10_000_000)
                        .frame(width: 90)
                    Text("KB")
                }
            }
            Toggle("Remove private metadata", isOn: $removePrivateMetadata)
            ResultCard(result: model.lastResult, sourceBytes: model.sourceBytes)
            if model.lastExportURL != nil {
                Button("Reveal in Finder", systemImage: "folder") {
                    model.revealLastExport()
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
            Button {
                model.optimize(parameters: parameters)
            } label: {
                Label("Optimize", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.activeData == nil || model.isWorking)
        }
        .onChange(of: preset) { _, value in
            let defaults = OptimizeParameters.parameters(for: value)
            format = availableFormats.contains(defaults.format) ? defaults.format : .jpeg
            quality = defaults.quality
            removePrivateMetadata = defaults.metadataPolicy == .removePrivate
            if let bytes = defaults.targetBytes {
                targetKilobytes = bytes / 1_000
            }
        }
    }

    private var parameters: OptimizeParameters {
        OptimizeParameters(
            preset: preset,
            format: format,
            quality: quality,
            resize: OptimizeParameters.parameters(for: preset).resize,
            metadataPolicy: removePrivateMetadata ? .removePrivate : .keepAll,
            targetBytes: preset == .targetSize ? targetKilobytes * 1_000 : nil
        )
    }

    private var availableFormats: [ImageFormat] {
        ImageFormat.allCases.filter {
            ImageEncoderService.supports($0)
        }
    }
}

private struct RemoveBackgroundInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var featherRadius = 1.5
    @State private var maskShift = 0.0
    @State private var background = BackgroundChoice.transparent

    private enum BackgroundChoice: String, CaseIterable, Identifiable {
        case transparent = "Transparent"
        case white = "White"
        case black = "Black"
        case blur = "Blur"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Remove Background", systemImage: "person.crop.rectangle")
                    .font(.title2.bold())
                Text("Detect subjects, choose which ones to keep, then paint corrections directly on the image.")
                    .foregroundStyle(.secondary)

                if model.backgroundMaskData == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Offline Apple Vision", systemImage: "checkmark.shield")
                        Label("Subject selection", systemImage: "person.2")
                        Label("Keep / Remove refinement brush", systemImage: "paintbrush")
                    }
                    .font(.callout)
                    Button {
                        model.removeBackground(
                            featherRadius: featherRadius,
                            maskShift: maskShift,
                            replacement: replacement
                        )
                    } label: {
                        Label("Auto Remove Background", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.activeData == nil || model.isWorking)

                    Button {
                        model.detectBackgroundSubjects()
                    } label: {
                        Label("Detect & Refine", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.activeData == nil || model.isWorking)
                } else {
                    if !model.backgroundAvailableInstances.isEmpty {
                        Text("Subjects to keep").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], alignment: .leading) {
                            ForEach(model.backgroundAvailableInstances, id: \.self) { instance in
                                Button {
                                    model.toggleBackgroundInstance(instance)
                                } label: {
                                    Label(
                                        "Subject \(instance)",
                                        systemImage: model.backgroundSelectedInstances.contains(instance)
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Picker("Refine brush", selection: $model.backgroundBrushKeepsMask) {
                        Text("Keep").tag(true)
                        Text("Remove").tag(false)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Brush size")
                            Spacer()
                            Text("\(Int(model.brushDiameter * 100))%").monospacedDigit()
                        }
                        Slider(value: $model.brushDiameter, in: 0.01...0.3)
                    }
                    HStack {
                        Button("Undo Stroke", systemImage: "arrow.uturn.backward") {
                            model.undoBackgroundRefineStroke()
                        }
                        .disabled(model.backgroundRefineDocument.isEmpty)
                        Button("Clear Strokes") { model.clearBackgroundRefinements() }
                            .disabled(model.backgroundRefineDocument.isEmpty)
                    }
                }

                LabeledContent("Background") {
                    Picker("Background", selection: $background) {
                        ForEach(BackgroundChoice.allCases) { choice in
                            Text(LocalizedStringKey(choice.rawValue)).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Feather")
                        Spacer()
                        Text("\(featherRadius, specifier: "%.1f") px").monospacedDigit()
                    }
                    Slider(value: $featherRadius, in: 0...12)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Edge shift")
                        Spacer()
                        Text("\(maskShift, specifier: "%+.0f") px").monospacedDigit()
                    }
                    Slider(value: $maskShift, in: -10...10, step: 1)
                }

                if model.backgroundMaskData != nil {
                    HStack {
                        Button("Start Over", role: .destructive) { model.clearBackgroundDraft() }
                        Button {
                            model.applyBackgroundRemoval(
                                featherRadius: featherRadius,
                                maskShift: maskShift,
                                replacement: replacement
                            )
                        } label: {
                            Label("Apply Removal", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                    }
                }
            }
        }
    }

    private var replacement: BackgroundReplacement {
        switch background {
        case .transparent: .transparent
        case .white: .solid(red: 1, green: 1, blue: 1)
        case .black: .solid(red: 0, green: 0, blue: 0)
        case .blur: .blurred(radius: 18)
        }
    }
}

private struct ResultCard: View {
    let result: OptimizeResult?
    let sourceBytes: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(ByteCountFormatter.string(fromByteCount: Int64(sourceBytes), countStyle: .file))
                Image(systemName: "arrow.right")
                Text(result.map { ByteCountFormatter.string(fromByteCount: Int64($0.outputBytes), countStyle: .file) } ?? "—")
                    .foregroundStyle(Color.accentColor)
            }
            .font(.title3.weight(.semibold))
            if let result {
                Text("Reduced \(Int(max(0, result.savingsFraction) * 100))%")
                    .foregroundStyle(result.savedBytes >= 0 ? .green : .orange)
            } else {
                Text("Result appears after Optimize")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            Text(model.statusText)
            Spacer()
            if let size = model.sourceSize {
                Text("\(size.width) × \(size.height)")
                    .monospacedDigit()
            }
            Divider().frame(height: 14)
            Button { model.adjustZoom(by: 0.8) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")
            .accessibilityLabel("Zoom Out")
            Button {
                model.resetCanvasView()
            } label: {
                Text(abs(model.zoomScale - 1) < 0.01 ? "Fit" : "\(Int(model.zoomScale * 100))%")
                    .monospacedDigit()
                    .frame(minWidth: 34)
            }
            .help("Fit image in window")
            .accessibilityLabel("Fit Image in Window")
            Button { model.adjustZoom(by: 1.25) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")
            .accessibilityLabel("Zoom In")
            Button {
                model.isPanMode.toggle()
            } label: {
                Image(systemName: "hand.draw")
                    .foregroundStyle(model.isPanMode ? Color.accentColor : .secondary)
            }
            .help(model.isPanMode ? "Pan mode on — drag the canvas" : "Enable pan mode")
            .accessibilityLabel(model.isPanMode ? "Disable Pan Mode" : "Enable Pan Mode")
            if model.lastExportURL != nil {
                Button {
                    model.revealLastExport()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal last export in Finder")
                .accessibilityLabel("Reveal Last Export in Finder")
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }
}
