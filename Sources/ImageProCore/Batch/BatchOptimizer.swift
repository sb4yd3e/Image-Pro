import Foundation

public enum OutputCollisionPolicy: String, Codable, Sendable {
    case replace
    case skip
    case uniqueName
}

public struct BatchRecipeOptions: Sendable {
    public var autoRemoveBackground: Bool
    public var preserveFolderStructure: Bool
    public var sourceRoot: URL?

    public init(
        autoRemoveBackground: Bool = false,
        preserveFolderStructure: Bool = false,
        sourceRoot: URL? = nil
    ) {
        self.autoRemoveBackground = autoRemoveBackground
        self.preserveFolderStructure = preserveFolderStructure
        self.sourceRoot = sourceRoot
    }
}

public struct BatchOptimizeItemResult: Sendable {
    public let inputURL: URL
    public let outputURL: URL?
    public let result: OptimizeResult?
    public let errorDescription: String?

    public var succeeded: Bool { result != nil }
}

public final class BatchOptimizer {
    public init() {}

    public func run(
        inputs: [URL],
        outputDirectory: URL,
        parameters: OptimizeParameters,
        collisionPolicy: OutputCollisionPolicy = .uniqueName,
        recipe: BatchRecipeOptions = BatchRecipeOptions(),
        shouldCancel: () -> Bool = { false },
        progress: (Int, Int) -> Void = { _, _ in }
    ) -> [BatchOptimizeItemResult] {
        var results: [BatchOptimizeItemResult] = []
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for (index, input) in inputs.enumerated() {
            guard !shouldCancel() else { break }
            let requestedFormat: ImageFormat
            if parameters.format == .automatic {
                requestedFormat = recipe.autoRemoveBackground ? .png : inferredFormat(from: input)
            } else {
                requestedFormat = parameters.format
            }
            let baseName = input.deletingPathExtension().lastPathComponent + "-optimized"
            let itemOutputDirectory = resolvedOutputDirectory(
                for: input,
                base: outputDirectory,
                recipe: recipe
            )
            try? fileManager.createDirectory(at: itemOutputDirectory, withIntermediateDirectories: true)
            let desired = itemOutputDirectory
                .appendingPathComponent(baseName)
                .appendingPathExtension(requestedFormat.fileExtension)
            let output = OutputURLResolver.resolve(desired, policy: collisionPolicy)

            guard let output else {
                results.append(BatchOptimizeItemResult(inputURL: input, outputURL: nil, result: nil, errorDescription: "Output exists"))
                progress(index + 1, inputs.count)
                continue
            }

            do {
                let sourceData = try Data(contentsOf: input)
                let recipeData: Data
                if recipe.autoRemoveBackground {
                    let decoded = try ImageIOService.decode(data: sourceData)
                    let cutout = try BackgroundRemovalService(
                        provider: VisionForegroundSegmenter()
                    ).removeBackground(from: decoded.image)
                    recipeData = try ImageEncoderService.encode(
                        image: cutout,
                        format: .png,
                        quality: 1,
                        sourceProperties: decoded.sourceProperties,
                        metadataPolicy: parameters.metadataPolicy
                    )
                } else {
                    recipeData = sourceData
                }
                var resolvedParameters = parameters
                resolvedParameters.format = requestedFormat
                let result = try SmartOptimizer().optimize(data: recipeData, parameters: resolvedParameters)
                try result.data.write(to: output, options: .atomic)
                if !recipe.autoRemoveBackground, result.outputBytes > result.sourceBytes {
                    try? fileManager.removeItem(at: output)
                    results.append(BatchOptimizeItemResult(
                        inputURL: input,
                        outputURL: nil,
                        result: nil,
                        errorDescription: "Optimized file was larger than the source"
                    ))
                } else {
                    results.append(BatchOptimizeItemResult(inputURL: input, outputURL: output, result: result, errorDescription: nil))
                }
            } catch {
                results.append(BatchOptimizeItemResult(
                    inputURL: input,
                    outputURL: output,
                    result: nil,
                    errorDescription: error.localizedDescription
                ))
            }
            progress(index + 1, inputs.count)
        }
        return results
    }

    private func resolvedOutputDirectory(
        for input: URL,
        base: URL,
        recipe: BatchRecipeOptions
    ) -> URL {
        guard
            recipe.preserveFolderStructure,
            let root = recipe.sourceRoot?.standardizedFileURL
        else { return base }
        let parent = input.standardizedFileURL.deletingLastPathComponent()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard parent.path == root.path || parent.path.hasPrefix(rootPath) else { return base }
        let relative = parent.path == root.path
            ? ""
            : String(parent.path.dropFirst(rootPath.count))
        return relative.isEmpty ? base : base.appendingPathComponent(relative, isDirectory: true)
    }

    private func inferredFormat(from input: URL) -> ImageFormat {
        if
            let data = try? Data(contentsOf: input),
            let decoded = try? ImageIOService.decode(data: data)
        {
            return ImageFormatClassifier.suggestedFormat(for: decoded.image)
        }
        return switch input.pathExtension.lowercased() {
        case "png": .png
        case "heic", "heif": .heic
        case "tif", "tiff": .tiff
        case "avif": .avif
        case "webp": .webP
        default: .jpeg
        }
    }
}
