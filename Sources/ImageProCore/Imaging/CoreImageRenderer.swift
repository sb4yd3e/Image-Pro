import CoreGraphics
import CoreImage
import Foundation

public final class CoreImageRenderer {
    public static let shared = CoreImageRenderer()

    private let context: CIContext

    public init(context: CIContext = CIContext(options: [
        .cacheIntermediates: true,
        .priorityRequestLow: false
    ])) {
        self.context = context
    }

    public func resized(_ image: CGImage, to target: PixelSize) throws -> CGImage {
        let source = CIImage(cgImage: image)
        let widthScale = Double(target.width) / source.extent.width
        let heightScale = Double(target.height) / source.extent.height

        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            throw ImageProcessingError.filterUnavailable("CILanczosScaleTransform")
        }
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(heightScale, forKey: kCIInputScaleKey)
        filter.setValue(widthScale / heightScale, forKey: kCIInputAspectRatioKey)

        guard let output = filter.outputImage else {
            throw ImageProcessingError.renderFailed
        }
        let bounds = CGRect(x: 0, y: 0, width: target.width, height: target.height)
        guard let rendered = context.createCGImage(output, from: bounds) else {
            throw ImageProcessingError.renderFailed
        }
        return rendered
    }

    public func render(_ image: CIImage, in bounds: CGRect? = nil) throws -> CGImage {
        let renderBounds = bounds ?? image.extent.integral
        guard !renderBounds.isEmpty, !renderBounds.isInfinite else {
            throw ImageProcessingError.renderFailed
        }
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -renderBounds.origin.x,
            y: -renderBounds.origin.y
        ))
        let outputBounds = CGRect(origin: .zero, size: renderBounds.size)
        guard let rendered = context.createCGImage(normalized, from: outputBounds) else {
            throw ImageProcessingError.renderFailed
        }
        return rendered
    }
}

public enum ImageProcessingError: Error, Equatable {
    case invalidImage
    case renderFailed
    case filterUnavailable(String)
    case destinationUnsupported(ImageFormat)
    case encodeFailed
    case targetSizeUnreachable
}

extension ImageProcessingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The image could not be decoded. Try exporting it as PNG or JPEG first."
        case .renderFailed:
            "The image could not be rendered. Try a smaller image or reset the current draft."
        case let .filterUnavailable(name):
            "The required image filter “\(name)” is unavailable on this Mac."
        case let .destinationUnsupported(format):
            "Exporting \(format.rawValue) is not supported by this macOS version."
        case .encodeFailed:
            "The result could not be encoded. Try PNG or JPEG."
        case .targetSizeUnreachable:
            "The requested target size cannot be reached with the current quality settings."
        }
    }
}
