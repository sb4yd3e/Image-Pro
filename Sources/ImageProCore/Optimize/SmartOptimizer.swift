import CoreGraphics
import Foundation

public final class SmartOptimizer {
    private let renderer: CoreImageRenderer

    public init(renderer: CoreImageRenderer = .shared) {
        self.renderer = renderer
    }

    public func optimize(
        data sourceData: Data,
        parameters: OptimizeParameters,
        sourceProperties overrideSourceProperties: [CFString: Any]? = nil
    ) throws -> OptimizeResult {
        let decoded = try ImageIOService.decode(data: sourceData)
        let sourceProperties = overrideSourceProperties ?? decoded.sourceProperties
        let requestedSize = targetPixelSize(for: decoded.pixelSize, intent: parameters.resize)
        let requestedImage = requestedSize == decoded.pixelSize
            ? decoded.image
            : try renderer.resized(decoded.image, to: requestedSize)
        let format = resolvedFormat(parameters.format, image: requestedImage)

        guard let targetBytes = parameters.targetBytes, targetBytes > 0 else {
            let output = try ImageEncoderService.encode(
                image: requestedImage,
                format: format,
                quality: parameters.quality,
                sourceProperties: sourceProperties,
                metadataPolicy: parameters.metadataPolicy,
                lossless: parameters.preset == .lossless
            )
            return OptimizeResult(
                sourceBytes: sourceData.count,
                outputBytes: output.count,
                format: format,
                pixelSize: requestedSize,
                quality: parameters.quality,
                data: output
            )
        }

        var currentSize = requestedSize
        var lastCandidate: TargetSizeCandidate?

        for _ in 0..<12 {
            let image = currentSize == decoded.pixelSize
                ? decoded.image
                : try renderer.resized(decoded.image, to: currentSize)
            let candidate = try TargetSizeSolver.solve(targetBytes: targetBytes) { quality in
                try ImageEncoderService.encode(
                    image: image,
                    format: format,
                    quality: format.isLossy ? quality : parameters.quality,
                    sourceProperties: sourceProperties,
                    metadataPolicy: parameters.metadataPolicy,
                    lossless: parameters.preset == .lossless
                )
            }
            lastCandidate = candidate
            if candidate.meetsTarget {
                return OptimizeResult(
                    sourceBytes: sourceData.count,
                    outputBytes: candidate.data.count,
                    format: format,
                    pixelSize: currentSize,
                    quality: candidate.quality,
                    data: candidate.data
                )
            }

            guard parameters.targetPriority != .preserveResolution else { break }
            let ratio = sqrt(Double(targetBytes) / Double(max(1, candidate.data.count))) * 0.92
            let scale = min(max(ratio, 0.5), 0.92)
            let next = currentSize.scaled(by: scale)
            guard next != currentSize, next.width >= 64, next.height >= 64 else { break }
            currentSize = next
        }

        guard let candidate = lastCandidate else {
            throw ImageProcessingError.targetSizeUnreachable
        }
        return OptimizeResult(
            sourceBytes: sourceData.count,
            outputBytes: candidate.data.count,
            format: format,
            pixelSize: currentSize,
            quality: candidate.quality,
            data: candidate.data
        )
    }

    public func optimize(fileAt inputURL: URL, to outputURL: URL, parameters: OptimizeParameters) throws -> OptimizeResult {
        let result = try optimize(data: Data(contentsOf: inputURL), parameters: parameters)
        try result.data.write(to: outputURL, options: .atomic)
        return result
    }

    private func targetPixelSize(for source: PixelSize, intent: ResizeIntent) -> PixelSize {
        switch intent {
        case .keepOriginal:
            source
        case .longEdge(let value):
            source.constrainedTo(longEdge: value)
        case .exact(let size):
            size
        }
    }

    private func resolvedFormat(_ requested: ImageFormat, image: CGImage) -> ImageFormat {
        guard requested == .automatic else { return requested }
        return ImageFormatClassifier.suggestedFormat(for: image)
    }
}
