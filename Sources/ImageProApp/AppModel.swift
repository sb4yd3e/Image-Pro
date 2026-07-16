import AppKit
import CoreImage
import Foundation
import ImageProCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    private struct PreparedPreview: Sendable {
        let data: Data
        let previewData: Data
        let pixelSize: PixelSize
    }

    enum ComparisonMode: String, CaseIterable, Identifiable {
        case before = "Before"
        case after = "After"
        case split = "Split"

        var id: String { rawValue }
    }

    enum Tool: String, CaseIterable, Identifiable {
        case batchQueue = "Batch Queue"
        case optimize = "Optimize"
        case removeBackground = "Remove BG"
        case cropResize = "Crop & Resize"
        case upscale = "Upscale"
        case erase = "Erase"
        case generate = "Generate"
        case ocr = "OCR"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .batchQueue: "clock"
            case .optimize: "sparkles"
            case .removeBackground: "person.crop.rectangle"
            case .cropResize: "crop"
            case .upscale: "arrow.up.left.and.arrow.down.right"
            case .erase: "eraser"
            case .generate: "wand.and.stars"
            case .ocr: "text.viewfinder"
            }
        }
    }

    @Published var selectedTool: Tool = .optimize
    @Published var image: NSImage?
    @Published var sourcePreviewImage: NSImage?
    @Published var imageURL: URL?
    @Published var sourceData: Data?
    @Published var activeData: Data?
    @Published var originalSize: PixelSize?
    @Published var sourceSize: PixelSize?
    @Published var sourceBytes: Int = 0
    @Published var statusText = "Drop an image to begin"
    @Published var isWorking = false
    @Published var lastResult: OptimizeResult?
    @Published var hasOptimizePreview = false
    @Published var errorMessage: String?
    @Published var hasAppliedEdit = false
    @Published var operationGraph = OperationGraph()
    @Published var comparisonMode: ComparisonMode = .after
    @Published var batchInputs: [URL] = []
    @Published var batchInputRoot: URL?
    @Published var batchOutputDirectory: URL?
    @Published var batchResults: [BatchOptimizeItemResult] = []
    @Published var batchJobs: [JobRecord] = []
    @Published var batchCompletedCount = 0
    @Published var isBatchRunning = false
    @Published var upscaleProgress = 0.0
    @Published var maskDocument = MaskDocument()
    @Published var brushDiameter = 0.08
    @Published var brushPaintsMask = true
    @Published var backgroundBrushKeepsMask = true
    @Published var generativeProgress = 0.0
    @Published var generatedVariants: [Data] = []
    @Published var selectedVariantIndex = 0
    @Published var recentFiles: [URL] = []
    @Published var comparisonFraction = 0.5
    @Published var isOutpaintMode = false
    @Published var cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
    @Published var cropAspectRatio: Double?
    @Published var zoomScale = 1.0
    @Published var panOffset = CGSize.zero
    @Published var isPanMode = false
    @Published var backgroundMaskData: Data?
    @Published var backgroundMaskPreviewImage: NSImage?
    @Published var backgroundRefineDocument = MaskDocument()
    @Published var backgroundAvailableInstances: [Int] = []
    @Published var backgroundSelectedInstances: Set<Int> = []
    @Published var lastExportURL: URL?
    @Published var ocrText = ""
    @Published var ocrBlocks: [OCRTextBlock] = []
    @Published var ocrSupportedLanguages: [String] = []
    @Published var ocrLanguage = ""
    @Published var ocrQuality: OCRRecognitionQuality = .accurate
    @Published var ocrUsesLanguageCorrection = true
    @Published var projectURL: URL?

    private var editingBaseData: Data?
    private var originalSourceProperties: [CFString: Any] = [:]
    private let jobQueue: JobQueue
    private var batchWorker: Task<[BatchOptimizeItemResult], Never>?
    private var batchRunID = UUID()
    private var generativeBaseData: Data?
    private var generativeBasePreviewImage: NSImage?
    private var generativeBaseSize: PixelSize?
    private var preparedGeneratedVariants: [PreparedPreview] = []
    private let projectStore = ProjectStore()
    private var autosaveTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var autosaveProjectID = UUID()
    private var autosaveCreatedAt = Date()
    private var renderedUndoStack: [Data] = []
    private var renderedRedoStack: [Data] = []
    private var backgroundBaseData: Data?
    private var optimizePreviewBaseData: Data?

    private static let previewMaxPixelDimension = 2_048
    private static let renderedHistoryLimit = 10

    private static let recentFilesKey = "recentImagePaths"

    init() {
        let stateURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Image Pro", isDirectory: true)
            .appendingPathComponent("batch-queue.json")
        jobQueue = JobQueue(persistenceURL: stateURL)
        recentFiles = (UserDefaults.standard.stringArray(forKey: Self.recentFilesKey) ?? [])
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        Task {
            batchJobs = await jobQueue.snapshot()
        }
    }

    var displayImage: NSImage? {
        guard comparisonMode == .before else { return image }
        return sourcePreviewImage
    }

    var canUndo: Bool { operationGraph.canUndo || !renderedUndoStack.isEmpty }
    var canRedo: Bool { operationGraph.canRedo || !renderedRedoStack.isEmpty }

    func chooseImage() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func pasteImageFromClipboard() {
        guard !isWorking else { return }
        let pasteboard = NSPasteboard.general
        guard
            let pasted = NSImage(pasteboard: pasteboard),
            let data = pasted.tiffRepresentation
        else {
            errorMessage = "The clipboard does not contain an image."
            return
        }
        prepareAndLoadImage(data: data, sourceURL: nil, displayName: "Clipboard image")
    }

    func copyCurrentImage() {
        guard let data = activeData, let copied = NSImage(data: data) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([copied])
        statusText = "Copied current image"
    }

    func saveProject() {
        guard let snapshot = currentProjectSnapshot() else { return }
        guard let projectURL else {
            saveProjectAs(snapshot: snapshot)
            return
        }
        persistProject(snapshot, to: projectURL)
    }

    func saveProjectAs() {
        guard let snapshot = currentProjectSnapshot() else { return }
        saveProjectAs(snapshot: snapshot)
    }

    private func saveProjectAs(snapshot: ProjectSnapshot) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(exportedAs: "local.imagepro.project", conformingTo: .package)]
        panel.nameFieldStringValue = projectURL?.lastPathComponent
            ?? (imageURL?.deletingPathExtension().lastPathComponent ?? "Image Pro Project") + ".imagepro"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        persistProject(snapshot, to: url)
    }

    private func persistProject(_ snapshot: ProjectSnapshot, to url: URL) {
        Task {
            do {
                try await projectStore.saveSnapshot(snapshot, to: url)
                projectURL = url
                statusText = "Saved project \(url.lastPathComponent)"
            } catch {
                errorMessage = "Could not save project: \(error.localizedDescription)"
            }
        }
    }

    func chooseProject() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(exportedAs: "local.imagepro.project", conformingTo: .package)]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(url)
    }

    func openDocument(_ url: URL) {
        if url.pathExtension.lowercased() == "imagepro" {
            guard projectURL != url else { return }
            openProject(url)
        } else {
            guard imageURL != url else { return }
            open(url)
        }
    }

    func openProject(_ url: URL) {
        guard !isWorking else { return }
        Task {
            do {
                let snapshot = try await projectStore.loadSnapshot(from: url)
                try restore(snapshot: snapshot, projectURL: url)
                statusText = "Opened project \(url.lastPathComponent)"
            } catch {
                errorMessage = "Could not open project: \(error.localizedDescription)"
            }
        }
    }

    func chooseBatchImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let existing = Set(batchInputs)
        batchInputs.append(contentsOf: panel.urls.filter { !existing.contains($0) })
        batchResults = []
    }

    func chooseBatchFolder() {
        guard !isBatchRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey, .isHiddenKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        let files = (FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: options
        )?.allObjects as? [URL] ?? []).filter { url in
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true,
                values.isHidden != true
            else { return false }
            return values.contentType?.conforms(to: .image) == true
        }
        let existing = Set(batchInputs.map(\.standardizedFileURL))
        let additions = files.filter { !existing.contains($0.standardizedFileURL) }.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        batchInputs.append(contentsOf: additions)
        batchInputRoot = directory
        batchResults = []
        statusText = "Added \(additions.count) image(s) from \(directory.lastPathComponent)"
    }

    func resetCanvasView() {
        zoomScale = 1
        panOffset = .zero
        isPanMode = false
    }

    func setZoom(_ value: Double) {
        zoomScale = min(max(value, 0.5), 8)
        if zoomScale <= 1 { panOffset = .zero }
    }

    func adjustZoom(by factor: Double) {
        setZoom(zoomScale * factor)
    }

    func updatePan(_ offset: CGSize) {
        panOffset = offset
    }

    func chooseBatchOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return }
        batchOutputDirectory = panel.url
    }

    func clearBatch() {
        guard !isBatchRunning else { return }
        batchInputs = []
        batchInputRoot = nil
        batchResults = []
        batchCompletedCount = 0
        Task {
            await jobQueue.clearFinished()
            batchJobs = await jobQueue.snapshot()
        }
    }

    func runBatch(
        parameters: OptimizeParameters,
        collisionPolicy: OutputCollisionPolicy,
        autoRemoveBackground: Bool = false,
        preserveFolderStructure: Bool = false
    ) {
        guard
            !isBatchRunning,
            !batchInputs.isEmpty,
            let outputDirectory = batchOutputDirectory
        else { return }

        let inputs = batchInputs
        let sourceRoot = batchInputRoot
        let runID = UUID()
        batchRunID = runID
        batchCompletedCount = 0
        batchResults = []
        isBatchRunning = true
        errorMessage = nil

        Task {
            var records: [JobRecord] = []
            for input in inputs {
                records.append(await jobQueue.enqueue(
                    kind: .optimize,
                    inputPath: input.path,
                    outputPath: outputDirectory.path
                ))
            }
            batchJobs = await jobQueue.snapshot()
            for record in records {
                await jobQueue.update(id: record.id, status: .running, progress: 0)
            }

            let worker = Task.detached(priority: .userInitiated) { [weak self] in
                BatchOptimizer().run(
                    inputs: inputs,
                    outputDirectory: outputDirectory,
                    parameters: parameters,
                    collisionPolicy: collisionPolicy,
                    recipe: BatchRecipeOptions(
                        autoRemoveBackground: autoRemoveBackground,
                        preserveFolderStructure: preserveFolderStructure,
                        sourceRoot: sourceRoot
                    ),
                    shouldCancel: { Task.isCancelled },
                    progress: { completed, _ in
                        Task { @MainActor [weak self] in
                            guard self?.batchRunID == runID else { return }
                            self?.batchCompletedCount = completed
                        }
                    }
                )
            }
            batchWorker = worker
            let results = await worker.value
            guard batchRunID == runID else { return }

            for (index, record) in records.enumerated() {
                if index < results.count {
                    let result = results[index]
                    await jobQueue.update(
                        id: record.id,
                        status: result.succeeded ? .completed : .failed,
                        progress: result.succeeded ? 1 : nil,
                        error: result.errorDescription
                    )
                } else {
                    await jobQueue.cancel(id: record.id)
                }
            }
            batchResults = results
            batchJobs = await jobQueue.snapshot()
            isBatchRunning = false
            batchWorker = nil
        }
    }

    func cancelBatch() {
        batchWorker?.cancel()
        statusText = "Cancelling batch…"
    }

    func cancelCurrentOperation() {
        processingTask?.cancel()
        statusText = "Cancelling…"
    }

    func appendMaskStroke(points: [MaskPoint]) {
        guard !points.isEmpty else { return }
        guard brushPaintsMask || maskDocument.hasPaintedContent else {
            brushPaintsMask = true
            statusText = "Choose Add Mask and paint the object first"
            return
        }
        maskDocument.append(MaskStroke(
            points: points,
            diameter: brushDiameter,
            paintsMask: brushPaintsMask
        ))
        scheduleAutosave()
    }

    func undoMaskStroke() {
        maskDocument.undo()
        scheduleAutosave()
    }

    func clearMask() {
        maskDocument.clear()
        scheduleAutosave()
    }

    func appendBackgroundRefineStroke(points: [MaskPoint]) {
        guard !points.isEmpty else { return }
        backgroundRefineDocument.append(MaskStroke(
            points: points,
            diameter: brushDiameter,
            paintsMask: backgroundBrushKeepsMask
        ))
        scheduleAutosave()
    }

    func undoBackgroundRefineStroke() {
        backgroundRefineDocument.undo()
        scheduleAutosave()
    }

    func clearBackgroundRefinements() {
        backgroundRefineDocument.clear()
        scheduleAutosave()
    }

    func clearRecentFiles() {
        recentFiles.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.recentFilesKey)
        statusText = "Recent files cleared"
    }

    func loadOCRLanguages() {
        do {
            ocrSupportedLanguages = try VisionTextRecognizer().supportedLanguages(quality: ocrQuality)
            if !ocrLanguage.isEmpty, !ocrSupportedLanguages.contains(ocrLanguage) {
                ocrLanguage = ""
            }
        } catch {
            errorMessage = "Could not load OCR languages: \(error.localizedDescription)"
        }
    }

    func recognizeText() {
        guard let data = activeData, !isWorking else { return }
        let quality = ocrQuality
        let language = ocrLanguage
        let correction = ocrUsesLanguageCorrection
        isWorking = true
        statusText = "Recognizing text on device…"
        errorMessage = nil

        processingTask = Task {
            do {
                let result = try await Self.runDetached {
                    let decoded = try ImageIOService.decode(data: data)
                    return try VisionTextRecognizer().recognize(
                        image: decoded.image,
                        quality: quality,
                        languages: language.isEmpty ? [] : [language],
                        usesLanguageCorrection: correction
                    )
                }
                ocrBlocks = result.blocks
                ocrText = result.text
                statusText = result.blocks.isEmpty
                    ? "No text found"
                    : "Recognized \(result.blocks.count) text line(s)"
            } catch {
                handleProcessingError(error, operation: "OCR")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func copyOCRText() {
        guard !ocrText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ocrText, forType: .string)
        statusText = "Copied recognized text"
    }

    func exportOCRText() {
        guard !ocrText.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = (imageURL?.deletingPathExtension().lastPathComponent ?? "recognized-text") + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ocrText.data(using: .utf8)?.write(to: url, options: .atomic)
            statusText = "Saved OCR text \(url.lastPathComponent)"
        } catch {
            errorMessage = "Could not save OCR text: \(error.localizedDescription)"
        }
    }

    func detectBackgroundSubjects(selecting requestedInstances: Set<Int>? = nil) {
        guard let data = backgroundBaseData ?? activeData, !isWorking else { return }
        isWorking = true
        statusText = "Detecting foreground subjects…"
        errorMessage = nil

        processingTask = Task {
            do {
                let result = try await Self.runDetached {
                    let decoded = try ImageIOService.decode(data: data)
                    let provider = VisionForegroundSegmenter()
                    let requested = IndexSet(requestedInstances ?? [])
                    let analysis = try provider.maskAndInstances(
                        for: decoded.image,
                        selectedInstances: requested
                    )
                    let mask = try CoreImageRenderer.shared.render(CIImage(cvPixelBuffer: analysis.mask))
                    let maskData = try ImageEncoderService.encode(
                        image: mask,
                        format: .png,
                        quality: 1,
                        sourceProperties: [:],
                        metadataPolicy: .removeAll
                    )
                    return (
                        maskData,
                        Array(analysis.availableInstances),
                        Set(analysis.selectedInstances)
                    )
                }
                backgroundBaseData = data
                backgroundMaskData = result.0
                backgroundMaskPreviewImage = try backgroundMaskPreview(for: result.0)
                backgroundAvailableInstances = result.1
                backgroundSelectedInstances = result.2
                if requestedInstances == nil { backgroundRefineDocument = MaskDocument() }
                comparisonMode = .after
                isPanMode = false
                statusText = "Detected \(result.1.count) foreground subject(s) — refine or apply"
            } catch {
                handleProcessingError(error, operation: "Foreground detection")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func toggleBackgroundInstance(_ instance: Int) {
        var selection = backgroundSelectedInstances
        if selection.contains(instance) {
            guard selection.count > 1 else { return }
            selection.remove(instance)
        } else {
            selection.insert(instance)
        }
        backgroundSelectedInstances = selection
        detectBackgroundSubjects(selecting: selection)
    }

    func applyBackgroundRemoval(
        featherRadius: Double = 1.5,
        maskShift: Double = 0,
        replacement: BackgroundReplacement = .transparent
    ) {
        guard
            let data = backgroundBaseData ?? activeData,
            let maskData = backgroundMaskData,
            !isWorking
        else { return }
        let refinements = backgroundRefineDocument
        isWorking = true
        statusText = "Applying background removal…"
        errorMessage = nil

        processingTask = Task {
            do {
                let output = try await Self.runDetached {
                    let decoded = try ImageIOService.decode(data: data)
                    let baseMask = try ImageIOService.decode(data: maskData).image
                    let refinedMask = try refinements.rasterized(
                        width: decoded.image.width,
                        height: decoded.image.height,
                        base: baseMask
                    )
                    let cutout = try BackgroundRemovalService(provider: VisionForegroundSegmenter()).composite(
                        image: decoded.image,
                        mask: refinedMask,
                        edge: BackgroundEdgeConfiguration(
                            featherRadius: featherRadius,
                            maskShift: maskShift
                        ),
                        replacement: replacement
                    )
                    let encoded = try ImageEncoderService.encode(
                        image: cutout,
                        format: .png,
                        quality: 1,
                        sourceProperties: decoded.sourceProperties,
                        metadataPolicy: .removePrivate
                    )
                    return try Self.preparedPreview(data: encoded)
                }
                try applyRenderedResult(output, status: "Background removed", undoData: data)
                statusText = replacement == .transparent
                    ? "Background removed — export as PNG/WebP to keep transparency"
                    : "Background replaced"
                clearBackgroundDraft()
            } catch {
                handleProcessingError(error, operation: "Background removal")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func clearBackgroundDraft() {
        backgroundMaskData = nil
        backgroundMaskPreviewImage = nil
        backgroundBaseData = nil
        backgroundRefineDocument = MaskDocument()
        backgroundAvailableInstances = []
        backgroundSelectedInstances = []
    }

    func upscaleWithRealESRGAN(scale: Int) {
        guard let data = activeData, !isWorking else { return }
        guard #available(macOS 15.0, *) else {
            errorMessage = "Real-ESRGAN requires macOS 15 or later"
            return
        }
        guard let modelURL = CoreMLModelSupport.installedModel(for: .upscale) else {
            errorMessage = "Install and activate an Upscale model in Settings › Models first."
            return
        }

        isWorking = true
        upscaleProgress = 0
        statusText = "Upscaling with Real-ESRGAN…"
        errorMessage = nil
        processingTask = Task {
            do {
                let output = try await Self.runDetached { [weak self] in
                    let decoded = try ImageIOService.decode(data: data)
                    let provider = try RealESRGANProvider(modelURL: modelURL)
                    let enhanced = try provider.upscale(decoded.image, scale: scale) { value in
                        Task { @MainActor [weak self] in self?.upscaleProgress = value }
                    }
                    let encoded = try ImageEncoderService.encode(
                        image: enhanced,
                        format: .png,
                        quality: 1,
                        sourceProperties: decoded.sourceProperties,
                        metadataPolicy: .removePrivate
                    )
                    return try Self.preparedPreview(data: encoded)
                }
                try applyRenderedResult(output, status: "Upscale \(scale)× complete")
            } catch {
                handleProcessingError(error, operation: "Upscale")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func eraseMaskedArea() {
        guard let data = activeData, !isWorking else { return }
        guard maskDocument.hasPaintedContent else {
            brushPaintsMask = true
            errorMessage = "Paint the object with Add Mask before running Erase."
            return
        }
        guard let modelURL = CoreMLModelSupport.installedModel(for: .erase) else {
            errorMessage = "Install and activate an Erase model in Settings › Models first."
            return
        }
        let mask = maskDocument
        isWorking = true
        statusText = "Smart Erase: rebuilding texture and blending edges…"
        errorMessage = nil

        processingTask = Task {
            do {
                let output = try await Self.runDetached {
                    let decoded = try ImageIOService.decode(data: data)
                    let maskImage = try mask.rasterized(
                        width: decoded.image.width,
                        height: decoded.image.height
                    )
                    let provider = try LaMaInpaintingProvider(modelURL: modelURL)
                    let result = try provider.inpaint(image: decoded.image, mask: maskImage)
                    try Task.checkCancellation()
                    let encoded = try ImageEncoderService.encode(
                        image: result,
                        format: .png,
                        quality: 1,
                        sourceProperties: decoded.sourceProperties,
                        metadataPolicy: .removePrivate
                    )
                    return try Self.preparedPreview(data: encoded)
                }
                try applyRenderedResult(output, status: "Object removed")
                maskDocument = MaskDocument()
            } catch {
                handleProcessingError(error, operation: "Object removal")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func generateMaskedFill(configuration: GenerativeFillConfiguration) {
        guard !isWorking else { return }
        guard maskDocument.hasPaintedContent else {
            brushPaintsMask = true
            errorMessage = "Paint the area with Add Mask before generating."
            return
        }
        let baseData = generativeBaseData ?? activeData
        guard let baseData else { return }
        guard let resourcesURL = stableDiffusionResourcesURL else {
            errorMessage = "Install and activate a Generate model in Settings › Models first."
            return
        }
        let mask = maskDocument
        generativeBaseData = baseData
        if generativeBasePreviewImage == nil {
            generativeBasePreviewImage = image
            generativeBaseSize = sourceSize
        }
        isWorking = true
        generativeProgress = 0
        statusText = "Generating fill…"
        errorMessage = nil

        processingTask = Task {
            do {
                let variants = try await Self.runDetached { [weak self] in
                    let decoded = try ImageIOService.decode(data: baseData)
                    let maskImage = try mask.rasterized(
                        width: decoded.image.width,
                        height: decoded.image.height
                    )
                    let provider = StableDiffusionGenerativeProvider(resourcesURL: resourcesURL)
                    let images = try provider.fill(
                        image: decoded.image,
                        mask: maskImage,
                        configuration: configuration
                    ) { value in
                        Task { @MainActor [weak self] in self?.generativeProgress = value }
                        return !Task.isCancelled
                    }
                    return try images.map {
                        let encoded = try ImageEncoderService.encode(
                            image: $0,
                            format: .png,
                            quality: 1,
                            sourceProperties: decoded.sourceProperties,
                            metadataPolicy: .removePrivate
                        )
                        return try Self.preparedPreview(data: encoded)
                    }
                }
                guard let first = variants.first else {
                    throw ImageProcessingError.renderFailed
                }
                preparedGeneratedVariants = variants
                generatedVariants = variants.map(\.data)
                selectedVariantIndex = 0
                activeData = first.data
                image = try previewImage(from: first)
                sourceSize = first.pixelSize
                comparisonMode = .after
                statusText = "Generated \(variants.count) variant(s)"
            } catch {
                handleProcessingError(error, operation: "Generative fill")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func generateOutpaint(
        configuration: GenerativeFillConfiguration,
        direction: OutpaintDirection,
        fraction: Double
    ) {
        guard !isWorking, let baseData = generativeBaseData ?? activeData else { return }
        guard let resourcesURL = stableDiffusionResourcesURL else {
            errorMessage = "Install and activate a Generate model in Settings › Models first."
            return
        }
        generativeBaseData = baseData
        if generativeBasePreviewImage == nil {
            generativeBasePreviewImage = image
            generativeBaseSize = sourceSize
        }
        isWorking = true
        generativeProgress = 0
        statusText = "Generating outpaint…"
        errorMessage = nil

        processingTask = Task {
            do {
                let variants = try await Self.runDetached { [weak self] in
                    let decoded = try ImageIOService.decode(data: baseData)
                    let canvas = try OutpaintCanvasBuilder.build(
                        image: decoded.image,
                        direction: direction,
                        fraction: fraction
                    )
                    let provider = StableDiffusionGenerativeProvider(resourcesURL: resourcesURL)
                    let images = try provider.fill(
                        image: canvas.image,
                        mask: canvas.mask,
                        configuration: configuration
                    ) { value in
                        Task { @MainActor [weak self] in self?.generativeProgress = value }
                        return !Task.isCancelled
                    }
                    return try images.map {
                        let encoded = try ImageEncoderService.encode(
                            image: $0,
                            format: .png,
                            quality: 1,
                            sourceProperties: decoded.sourceProperties,
                            metadataPolicy: .removePrivate
                        )
                        return try Self.preparedPreview(data: encoded)
                    }
                }
                guard let first = variants.first else { throw ImageProcessingError.renderFailed }
                preparedGeneratedVariants = variants
                generatedVariants = variants.map(\.data)
                selectedVariantIndex = 0
                activeData = first.data
                image = try previewImage(from: first)
                sourceSize = first.pixelSize
                comparisonMode = .after
                statusText = "Generated \(variants.count) outpaint variant(s)"
            } catch {
                handleProcessingError(error, operation: "Outpaint")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func selectGeneratedVariant(_ index: Int) {
        guard preparedGeneratedVariants.indices.contains(index) else { return }
        let selected = preparedGeneratedVariants[index]
        selectedVariantIndex = index
        activeData = selected.data
        image = try? previewImage(from: selected)
        sourceSize = selected.pixelSize
    }

    func applyGeneratedVariant() {
        guard preparedGeneratedVariants.indices.contains(selectedVariantIndex) else { return }
        let selected = preparedGeneratedVariants[selectedVariantIndex]
        do {
            try applyRenderedResult(
                selected,
                status: "Generative fill applied",
                undoData: generativeBaseData
            )
            generatedVariants = []
            preparedGeneratedVariants = []
            generativeBaseData = nil
            generativeBasePreviewImage = nil
            generativeBaseSize = nil
            maskDocument = MaskDocument()
        } catch {
            errorMessage = "Could not apply generated result: \(error.localizedDescription)"
        }
    }

    func discardGeneratedVariants() {
        guard let baseData = generativeBaseData else { return }
        activeData = baseData
        image = generativeBasePreviewImage
        sourceSize = generativeBaseSize
        generatedVariants = []
        preparedGeneratedVariants = []
        generativeBaseData = nil
        generativeBasePreviewImage = nil
        generativeBaseSize = nil
        selectedVariantIndex = 0
        statusText = "Generated draft discarded"
    }

    func open(_ url: URL) {
        guard !isWorking else { return }
        isWorking = true
        statusText = "Preparing image preview…"
        errorMessage = nil
        processingTask = Task {
            do {
                let prepared = try await Self.runDetached {
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    return try Self.preparedPreview(data: data)
                }
                try Task.checkCancellation()
                loadImageData(
                    prepared.data,
                    sourceURL: url,
                    displayName: url.lastPathComponent,
                    preparedPreviewData: prepared.previewData
                )
                addRecentFile(url)
            } catch {
                handleProcessingError(error, operation: "Open image")
            }
            isWorking = false
            processingTask = nil
        }
    }

    private func prepareAndLoadImage(data: Data, sourceURL: URL?, displayName: String) {
        isWorking = true
        statusText = "Preparing image preview…"
        errorMessage = nil
        processingTask = Task {
            do {
                let prepared = try await Self.runDetached {
                    try Self.preparedPreview(data: data)
                }
                try Task.checkCancellation()
                loadImageData(
                    prepared.data,
                    sourceURL: sourceURL,
                    displayName: displayName,
                    preparedPreviewData: prepared.previewData
                )
            } catch {
                handleProcessingError(error, operation: "Open image")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func export(parameters: OptimizeParameters) {
        guard let sourceData = activeData else { return }
        let resolvedFormat = resolvedExportFormat(parameters.format)
        let resolvedParameters: OptimizeParameters = {
            var value = parameters
            value.format = resolvedFormat
            return value
        }()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedExportName(format: resolvedFormat)
        panel.allowedContentTypes = [UTType(resolvedFormat.typeIdentifier) ?? .image]
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        isWorking = true
        statusText = "Optimizing…"
        errorMessage = nil
        processingTask = Task {
            do {
                let sourceProperties = originalSourceProperties
                let result = try await Self.runDetached {
                    try SmartOptimizer().optimize(
                        data: sourceData,
                        parameters: resolvedParameters,
                        sourceProperties: sourceProperties
                    )
                }
                try Task.checkCancellation()
                try result.data.write(to: outputURL, options: .atomic)
                lastResult = result
                lastExportURL = outputURL
                statusText = "Saved \(outputURL.lastPathComponent)"
            } catch {
                handleProcessingError(error, operation: "Export")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func optimize(parameters: OptimizeParameters) {
        guard !isWorking, let currentData = activeData else { return }
        let source = hasOptimizePreview ? (optimizePreviewBaseData ?? currentData) : currentData
        let resolvedFormat = resolvedExportFormat(parameters.format)
        var resolvedParameters = parameters
        resolvedParameters.format = resolvedFormat
        let finalParameters = resolvedParameters
        let sourceProperties = originalSourceProperties

        isWorking = true
        statusText = "Optimizing preview…"
        errorMessage = nil
        processingTask = Task {
            do {
                let prepared = try await Self.runDetached {
                    let result = try SmartOptimizer().optimize(
                        data: source,
                        parameters: finalParameters,
                        sourceProperties: sourceProperties
                    )
                    return (result, try Self.preparedPreview(data: result.data))
                }
                try Task.checkCancellation()
                try applyRenderedResult(
                    prepared.1,
                    status: "Optimized preview — review Before/After, then Export",
                    undoData: source
                )
                optimizePreviewBaseData = source
                lastResult = prepared.0
                hasOptimizePreview = true
            } catch {
                handleProcessingError(error, operation: "Optimize")
            }
            isWorking = false
            processingTask = nil
        }
    }

    private func savePreparedOptimizeResult(_ result: OptimizeResult) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedExportName(format: result.format)
        panel.allowedContentTypes = [UTType(result.format.typeIdentifier) ?? .image]
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        isWorking = true
        statusText = "Saving optimized image…"
        errorMessage = nil
        processingTask = Task {
            do {
                try await Self.runDetached {
                    try result.data.write(to: outputURL, options: .atomic)
                }
                try Task.checkCancellation()
                lastExportURL = outputURL
                statusText = "Saved \(outputURL.lastPathComponent)"
            } catch {
                handleProcessingError(error, operation: "Export")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func removeBackground(
        featherRadius: Double = 1.5,
        maskShift: Double = 0,
        replacement: BackgroundReplacement = .transparent
    ) {
        guard let data = activeData, !isWorking else { return }
        isWorking = true
        statusText = "Detecting foreground…"
        errorMessage = nil
        processingTask = Task {
            do {
                let output = try await Self.runDetached {
                    let decoded = try ImageIOService.decode(data: data)
                    let provider = VisionForegroundSegmenter()
                    let cutout = try BackgroundRemovalService(provider: provider).removeBackground(
                        from: decoded.image,
                        edge: BackgroundEdgeConfiguration(
                            featherRadius: featherRadius,
                            maskShift: maskShift
                        ),
                        replacement: replacement
                    )
                    let encoded = try ImageEncoderService.encode(
                        image: cutout,
                        format: .png,
                        quality: 1,
                        sourceProperties: decoded.sourceProperties,
                        metadataPolicy: .removePrivate
                    )
                    return try Self.preparedPreview(data: encoded)
                }
                try applyRenderedResult(output, status: "Background removed", undoData: data)
                statusText = replacement == .transparent
                    ? "Background removed — export as PNG/WebP to keep transparency"
                    : "Background replaced"
                scheduleAutosave()
            } catch {
                handleProcessingError(error, operation: "Background removal")
            }
            isWorking = false
            processingTask = nil
        }
    }

    func resetToOriginal() {
        guard let sourceData else { return }
        activeData = sourceData
        editingBaseData = sourceData
        image = sourcePreviewImage ?? (try? previewImage(for: sourceData))
        sourceSize = originalSize ?? (try? ImageIOService.inspect(data: sourceData).pixelSize)
        hasAppliedEdit = false
        operationGraph = OperationGraph()
        renderedUndoStack = []
        renderedRedoStack = []
        maskDocument = MaskDocument()
        generatedVariants = []
        preparedGeneratedVariants = []
        generativeBaseData = nil
        generativeBasePreviewImage = nil
        generativeBaseSize = nil
        clearBackgroundDraft()
        comparisonMode = .after
        lastResult = nil
        hasOptimizePreview = false
        optimizePreviewBaseData = nil
        lastExportURL = nil
        resetCanvasView()
        statusText = "Reverted to original"
        scheduleAutosave()
    }

    func applyCrop(xPercent: Double, yPercent: Double, widthPercent: Double, heightPercent: Double) {
        let operation = EditOperation.crop(CropParameters(
            normalizedX: xPercent / 100,
            normalizedY: yPercent / 100,
            normalizedWidth: widthPercent / 100,
            normalizedHeight: heightPercent / 100
        ))
        apply(operation, status: "Crop applied")
    }

    func applyCropSelection() {
        let rect = cropSelection
        applyCrop(
            xPercent: rect.minX * 100,
            yPercent: rect.minY * 100,
            widthPercent: rect.width * 100,
            heightPercent: rect.height * 100
        )
        cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func exportDefault() {
        if hasOptimizePreview, let lastResult {
            savePreparedOptimizeResult(lastResult)
            return
        }
        export(parameters: OptimizeParameters(
            preset: .balanced,
            format: .automatic,
            quality: 0.9,
            resize: .keepOriginal,
            metadataPolicy: .removePrivate
        ))
    }

    func applyResize(width: Int, height: Int, mode: ResizeMode) {
        apply(
            .resize(ResizeParameters(size: PixelSize(width: width, height: height), mode: mode)),
            status: "Resized to \(width) × \(height)"
        )
    }

    func rotate(by degrees: Double) {
        apply(.rotate(RotationParameters(degrees: degrees)), status: "Rotated \(Int(abs(degrees)))°")
    }

    func flip(horizontal: Bool) {
        apply(
            .rotate(RotationParameters(
                degrees: 0,
                flippedHorizontally: horizontal,
                flippedVertically: !horizontal
            )),
            status: horizontal ? "Flipped horizontally" : "Flipped vertically"
        )
    }

    func undo() {
        if operationGraph.canUndo {
            let previous = operationGraph
            operationGraph.undo()
            renderOperationGraph(fallback: previous, status: "Undo")
        } else if let previousData = renderedUndoStack.popLast(), let currentData = activeData {
            renderedRedoStack.append(currentData)
            trimRenderedHistory(&renderedRedoStack)
            restoreRenderedState(previousData, status: "Undo AI edit")
        }
    }

    func redo() {
        if operationGraph.canRedo {
            let previous = operationGraph
            operationGraph.redo()
            renderOperationGraph(fallback: previous, status: "Redo")
        } else if let nextData = renderedRedoStack.popLast(), let currentData = activeData {
            renderedUndoStack.append(currentData)
            trimRenderedHistory(&renderedUndoStack)
            restoreRenderedState(nextData, status: "Redo AI edit")
        }
    }

    private func apply(_ operation: EditOperation, status: String) {
        guard editingBaseData != nil, !isWorking else { return }
        let previous = operationGraph
        operationGraph.append(operation)
        renderOperationGraph(fallback: previous, status: status)
    }

    private func renderOperationGraph(fallback: OperationGraph, status: String) {
        guard let baseData = editingBaseData else { return }
        let operations = Array(operationGraph.activeOperations)
        isWorking = true
        statusText = "Rendering edit…"
        errorMessage = nil

        processingTask = Task {
            do {
                let output = try await Self.runDetached {
                    let encoded: Data
                    if operations.isEmpty {
                        encoded = baseData
                    } else {
                        let decoded = try ImageIOService.decode(data: baseData)
                        let rendered = try EditOperationRenderer().render(decoded.image, operations: operations)
                        encoded = try ImageEncoderService.encode(
                            image: rendered,
                            format: .png,
                            quality: 1,
                            sourceProperties: decoded.sourceProperties,
                            metadataPolicy: .removeAll
                        )
                    }
                    return try Self.preparedPreview(data: encoded)
                }
                activeData = output.data
                image = try previewImage(from: output)
                sourceSize = output.pixelSize
                hasAppliedEdit = !operations.isEmpty || baseData != sourceData
                comparisonMode = .after
                lastResult = nil
                hasOptimizePreview = false
                optimizePreviewBaseData = nil
                clearBackgroundDraft()
                statusText = status
                scheduleAutosave()
            } catch {
                operationGraph = fallback
                handleProcessingError(error, operation: "Edit")
            }
            isWorking = false
            processingTask = nil
        }
    }

    private func suggestedExportName(format: ImageFormat) -> String {
        let stem = imageURL?.deletingPathExtension().lastPathComponent ?? "image"
        return "\(stem)-optimized.\(format.fileExtension)"
    }

    private func resolvedExportFormat(_ requested: ImageFormat) -> ImageFormat {
        guard requested == .automatic else { return requested }
        var proposed = CGRect(origin: .zero, size: image?.size ?? .zero)
        guard let preview = image?.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
            return .jpeg
        }
        return ImageFormatClassifier.suggestedFormat(for: preview)
    }

    private func applyRenderedResult(_ output: PreparedPreview, status: String, undoData: Data? = nil) throws {
        if let previous = undoData ?? activeData, previous != output.data {
            renderedUndoStack.append(previous)
            trimRenderedHistory(&renderedUndoStack)
            renderedRedoStack = []
        }
        activeData = output.data
        editingBaseData = output.data
        clearBackgroundDraft()
        image = try previewImage(from: output)
        sourceSize = output.pixelSize
        operationGraph = OperationGraph()
        comparisonMode = .after
        hasAppliedEdit = true
        lastResult = nil
        hasOptimizePreview = false
        optimizePreviewBaseData = nil
        statusText = status
        scheduleAutosave()
    }

    private func restoreRenderedState(_ data: Data, status: String) {
        guard
            let info = try? ImageIOService.inspect(data: data),
            let preview = try? previewImage(for: data)
        else { return }
        activeData = data
        editingBaseData = data
        image = preview
        sourceSize = info.pixelSize
        operationGraph = OperationGraph()
        comparisonMode = .after
        hasAppliedEdit = data != sourceData
        lastResult = nil
        hasOptimizePreview = false
        optimizePreviewBaseData = nil
        statusText = status
        scheduleAutosave()
    }

    func revealLastExport() {
        guard let lastExportURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastExportURL])
    }

    private func previewImage(for data: Data) throws -> NSImage {
        let preview = try ImageIOService.preview(
            data: data,
            maxPixelDimension: 2_048
        )
        return NSImage(
            cgImage: preview,
            size: NSSize(width: preview.width, height: preview.height)
        )
    }

    private func previewImage(from prepared: PreparedPreview) throws -> NSImage {
        guard let preview = NSImage(data: prepared.previewData) else {
            throw ImageProcessingError.invalidImage
        }
        return preview
    }

    private func backgroundMaskPreview(for data: Data) throws -> NSImage {
        let mask = try ImageIOService.preview(
            data: data,
            maxPixelDimension: Self.previewMaxPixelDimension
        )
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            throw ImageProcessingError.filterUnavailable("CIColorMatrix")
        }
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.setValue(CIImage(cgImage: mask), forKey: kCIInputImageKey)
        filter.setValue(zero, forKey: "inputRVector")
        filter.setValue(zero, forKey: "inputGVector")
        filter.setValue(zero, forKey: "inputBVector")
        filter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputAVector")
        filter.setValue(CIVector(x: 0.12, y: 1, z: 0.25, w: 0), forKey: "inputBiasVector")
        guard let output = filter.outputImage else { throw ImageProcessingError.renderFailed }
        let rendered = try CoreImageRenderer.shared.render(output, in: output.extent)
        return NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
    }

    private func trimRenderedHistory(_ stack: inout [Data]) {
        if stack.count > Self.renderedHistoryLimit {
            stack.removeFirst(stack.count - Self.renderedHistoryLimit)
        }
    }

    private func handleProcessingError(_ error: Error, operation: String) {
        if Task.isCancelled || error is CancellationError {
            errorMessage = nil
            statusText = "Cancelled"
        } else if error as? VisionForegroundError == .noForegroundFound {
            let isThai = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
                == AppLanguage.thai.rawValue
            errorMessage = isThai
                ? "ไม่พบตัวแบบด้านหน้าที่ชัดเจน ลองใช้ ‘ตรวจจับและปรับแต่ง’ ครอบรูปให้ใกล้ตัวแบบมากขึ้น หรือใช้ ‘ลบวัตถุ’ สำหรับภาพกราฟิกพื้นเรียบ"
                : error.localizedDescription
            statusText = isThai ? "ไม่พบตัวแบบด้านหน้า" : "No foreground subject found"
        } else {
            errorMessage = "\(operation) failed: \(error.localizedDescription)"
            statusText = "\(operation) failed"
        }
    }

    private func loadImageData(
        _ data: Data,
        sourceURL: URL?,
        displayName: String,
        preparedPreviewData: Data? = nil
    ) {
        do {
            let info = try ImageIOService.inspect(data: data)
            let preview: NSImage
            if let preparedPreviewData, let prepared = NSImage(data: preparedPreviewData) {
                preview = prepared
            } else {
                preview = try previewImage(for: data)
            }
            imageURL = sourceURL
            projectURL = nil
            sourceData = data
            activeData = data
            editingBaseData = data
            sourceBytes = data.count
            originalSourceProperties = info.sourceProperties
            originalSize = info.pixelSize
            sourceSize = info.pixelSize
            image = preview
            sourcePreviewImage = preview
            lastResult = nil
            hasOptimizePreview = false
            optimizePreviewBaseData = nil
            hasAppliedEdit = false
            operationGraph = OperationGraph()
            renderedUndoStack = []
            renderedRedoStack = []
            maskDocument = MaskDocument()
            generatedVariants = []
            preparedGeneratedVariants = []
            generativeBaseData = nil
            generativeBasePreviewImage = nil
            generativeBaseSize = nil
            ocrText = ""
            ocrBlocks = []
            clearBackgroundDraft()
            autosaveProjectID = UUID()
            autosaveCreatedAt = Date()
            comparisonMode = .after
            cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
            cropAspectRatio = nil
            resetCanvasView()
            lastExportURL = nil
            statusText = displayName
            errorMessage = nil
            scheduleAutosave()
        } catch {
            errorMessage = "Could not open image: \(error.localizedDescription)"
        }
    }

    private func currentProjectSnapshot() -> ProjectSnapshot? {
        guard let sourceData, let editingBaseData, let activeData else { return nil }
        return ProjectSnapshot(
            document: ProjectDocument(
                id: autosaveProjectID,
                sourceRelativePath: "assets/original.image",
                sourceSHA256: ModelValidator.sha256(of: sourceData),
                editingBaseRelativePath: "assets/editing-base.image",
                activeRelativePath: "renders/previews/current.image",
                operationGraph: operationGraph,
                maskDocument: maskDocument,
                createdAt: autosaveCreatedAt
            ),
            sourceData: sourceData,
            editingBaseData: editingBaseData,
            activeData: activeData,
            renderedUndoData: renderedUndoStack,
            renderedRedoData: renderedRedoStack
        )
    }

    private func restore(snapshot: ProjectSnapshot, projectURL: URL?) throws {
        guard ModelValidator.sha256(of: snapshot.sourceData) == snapshot.document.sourceSHA256 else {
            throw ImageProcessingError.invalidImage
        }
        let preview = try previewImage(for: snapshot.activeData)
        let sourcePreview = try previewImage(for: snapshot.sourceData)
        let sourceInfo = try ImageIOService.inspect(data: snapshot.sourceData)
        let activeInfo = try ImageIOService.inspect(data: snapshot.activeData)

        sourceData = snapshot.sourceData
        activeData = snapshot.activeData
        editingBaseData = snapshot.editingBaseData
        sourceBytes = snapshot.sourceData.count
        originalSourceProperties = sourceInfo.sourceProperties
        originalSize = sourceInfo.pixelSize
        sourceSize = activeInfo.pixelSize
        image = preview
        sourcePreviewImage = sourcePreview
        operationGraph = snapshot.document.operationGraph
        maskDocument = snapshot.document.maskDocument ?? MaskDocument()
        renderedUndoStack = Array(snapshot.renderedUndoData.suffix(Self.renderedHistoryLimit))
        renderedRedoStack = Array(snapshot.renderedRedoData.suffix(Self.renderedHistoryLimit))
        autosaveProjectID = snapshot.document.id
        autosaveCreatedAt = snapshot.document.createdAt
        self.projectURL = projectURL
        imageURL = nil
        ocrText = ""
        ocrBlocks = []
        hasAppliedEdit = snapshot.activeData != snapshot.sourceData
        comparisonMode = .after
        resetCanvasView()
        scheduleAutosave()
    }

    private var autosavePackageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Image Pro", isDirectory: true)
            .appendingPathComponent("Autosave.imagepro", isDirectory: true)
    }

    private func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        recentFiles.insert(url, at: 0)
        recentFiles = Array(recentFiles.prefix(6))
        UserDefaults.standard.set(recentFiles.map(\.path), forKey: Self.recentFilesKey)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            await self.saveAutosavedSession()
        }
    }

    private func saveAutosavedSession() async {
        guard let snapshot = currentProjectSnapshot() else { return }
        try? await projectStore.saveSnapshot(snapshot, to: autosavePackageURL)
    }

    private var stableDiffusionResourcesURL: URL? {
        if
            let installed = InstalledModelLocator.model(for: .generate),
            installed.manifest.engine == .appleStableDiffusion,
            let url = InstalledModelLocator.url(for: .generate)
        {
            return url
        }
        #if DEBUG
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Models/Optional/StableDiffusion", isDirectory: true)
        return FileManager.default.fileExists(atPath: development.path) ? development : nil
        #else
        return nil
        #endif
    }

    private nonisolated static func preparedPreview(data: Data) throws -> PreparedPreview {
        let info = try ImageIOService.inspect(data: data)
        let preview = try ImageIOService.preview(
            data: data,
            maxPixelDimension: 2_048
        )
        let previewData = try ImageEncoderService.encode(
            image: preview,
            format: .png,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        return PreparedPreview(data: data, previewData: previewData, pixelSize: info.pixelSize)
    }

    private nonisolated static func runDetached<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let worker = Task.detached(priority: .userInitiated, operation: operation)
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
