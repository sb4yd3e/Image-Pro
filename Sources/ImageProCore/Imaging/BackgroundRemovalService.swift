import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

public protocol ForegroundMaskProviding: AnyObject {
    func mask(for image: CGImage, instances: IndexSet) throws -> CVPixelBuffer
}

public extension ForegroundMaskProviding {
    func mask(for image: CGImage) throws -> CVPixelBuffer {
        try mask(for: image, instances: IndexSet())
    }
}

public struct BackgroundEdgeConfiguration: Equatable, Sendable {
    public var featherRadius: Double
    public var maskShift: Double

    public init(featherRadius: Double = 1.5, maskShift: Double = 0) {
        self.featherRadius = min(max(featherRadius, 0), 30)
        self.maskShift = min(max(maskShift, -20), 20)
    }
}

public enum BackgroundReplacement: Equatable, Sendable {
    case transparent
    case solid(red: Double, green: Double, blue: Double, alpha: Double = 1)
    case blurred(radius: Double)
}

public final class BackgroundRemovalService {
    private let provider: any ForegroundMaskProviding
    private let renderer: CoreImageRenderer

    public init(provider: any ForegroundMaskProviding, renderer: CoreImageRenderer = .shared) {
        self.provider = provider
        self.renderer = renderer
    }

    public func removeBackground(
        from image: CGImage,
        instances: IndexSet = IndexSet(),
        edge: BackgroundEdgeConfiguration = BackgroundEdgeConfiguration(),
        replacement: BackgroundReplacement = .transparent
    ) throws -> CGImage {
        let mask = try provider.mask(for: image, instances: instances)
        return try composite(image: image, mask: mask, edge: edge, replacement: replacement)
    }

    public func composite(
        image: CGImage,
        mask: CVPixelBuffer,
        edge: BackgroundEdgeConfiguration = BackgroundEdgeConfiguration(),
        replacement: BackgroundReplacement = .transparent
    ) throws -> CGImage {
        try composite(
            image: image,
            maskImage: CIImage(cvPixelBuffer: mask),
            edge: edge,
            replacement: replacement
        )
    }

    public func composite(
        image: CGImage,
        mask: CGImage,
        edge: BackgroundEdgeConfiguration = BackgroundEdgeConfiguration(),
        replacement: BackgroundReplacement = .transparent
    ) throws -> CGImage {
        try composite(
            image: image,
            maskImage: CIImage(cgImage: mask),
            edge: edge,
            replacement: replacement
        )
    }

    private func composite(
        image: CGImage,
        maskImage initialMaskImage: CIImage,
        edge: BackgroundEdgeConfiguration,
        replacement: BackgroundReplacement
    ) throws -> CGImage {
        let input = CIImage(cgImage: image)
        var maskImage = initialMaskImage
        if maskImage.extent.size != input.extent.size {
            maskImage = maskImage.transformed(by: CGAffineTransform(
                scaleX: input.extent.width / maskImage.extent.width,
                y: input.extent.height / maskImage.extent.height
            ))
        }
        if edge.maskShift > 0 {
            maskImage = maskImage.applyingFilter(
                "CIMorphologyMaximum",
                parameters: [kCIInputRadiusKey: edge.maskShift]
            )
        } else if edge.maskShift < 0 {
            maskImage = maskImage.applyingFilter(
                "CIMorphologyMinimum",
                parameters: [kCIInputRadiusKey: abs(edge.maskShift)]
            )
        }
        if edge.featherRadius > 0 {
            maskImage = maskImage
                .clampedToExtent()
                .applyingFilter(
                    "CIGaussianBlur",
                    parameters: [kCIInputRadiusKey: edge.featherRadius]
                )
                .cropped(to: input.extent)
        }

        let background: CIImage
        switch replacement {
        case .transparent:
            background = CIImage(color: .clear).cropped(to: input.extent)
        case let .solid(red, green, blue, alpha):
            background = CIImage(color: CIColor(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )).cropped(to: input.extent)
        case let .blurred(radius):
            background = input
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(0, radius)])
                .cropped(to: input.extent)
        }
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw ImageProcessingError.filterUnavailable("CIBlendWithMask")
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        filter.setValue(maskImage, forKey: kCIInputMaskImageKey)
        guard let output = filter.outputImage else {
            throw ImageProcessingError.renderFailed
        }
        return try renderer.render(output, in: input.extent)
    }
}
