import CoreGraphics
import CoreImage
import Foundation

public final class EditOperationRenderer {
    private let renderer: CoreImageRenderer

    public init(renderer: CoreImageRenderer = .shared) {
        self.renderer = renderer
    }

    public func render(_ source: CGImage, operations: some Sequence<EditOperation>) throws -> CGImage {
        var image = source
        for operation in operations {
            switch operation {
            case .crop(let parameters):
                image = try crop(image, parameters: parameters)
            case .resize(let parameters):
                image = try resize(image, parameters: parameters)
            case .rotate(let parameters):
                image = try rotate(image, parameters: parameters)
            case .backgroundMask, .inpaint, .upscale, .optimizePreview:
                continue
            }
        }
        return image
    }

    private func crop(_ image: CGImage, parameters: CropParameters) throws -> CGImage {
        let pixelX = min(
            max(Int((clamp(parameters.normalizedX) * CGFloat(image.width)).rounded(.down)), 0),
            image.width - 1
        )
        let pixelTopY = min(
            max(Int((clamp(parameters.normalizedY) * CGFloat(image.height)).rounded(.down)), 0),
            image.height - 1
        )
        let requestedWidth = max(1, Int((clamp(parameters.normalizedWidth) * CGFloat(image.width)).rounded()))
        let requestedHeight = max(1, Int((clamp(parameters.normalizedHeight) * CGFloat(image.height)).rounded()))
        let cropWidth = min(requestedWidth, image.width - pixelX)
        let cropHeight = min(requestedHeight, image.height - pixelTopY)
        let coreImageY = image.height - pixelTopY - cropHeight
        let rect = CGRect(x: pixelX, y: coreImageY, width: cropWidth, height: cropHeight)
        let cropped = CIImage(cgImage: image).cropped(to: rect)
        return try renderer.render(cropped, in: rect)
    }

    private func resize(_ image: CGImage, parameters: ResizeParameters) throws -> CGImage {
        let sourceSize = PixelSize(width: image.width, height: image.height)
        switch parameters.mode {
        case .stretch:
            return try renderer.resized(image, to: parameters.size)
        case .fit:
            return try renderer.resized(image, to: sourceSize.fitting(within: parameters.size, allowUpscale: true))
        case .fill:
            let filledSize = sourceSize.filling(parameters.size)
            let resized = try renderer.resized(image, to: filledSize)
            let x = max(0, (filledSize.width - parameters.size.width) / 2)
            let y = max(0, (filledSize.height - parameters.size.height) / 2)
            guard let result = resized.cropping(to: CGRect(x: x, y: y, width: parameters.size.width, height: parameters.size.height)) else {
                throw ImageProcessingError.renderFailed
            }
            return result
        }
    }

    private func rotate(_ image: CGImage, parameters: RotationParameters) throws -> CGImage {
        var ciImage = CIImage(cgImage: image)
        let center = CGPoint(x: ciImage.extent.midX, y: ciImage.extent.midY)
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        if parameters.flippedHorizontally {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        if parameters.flippedVertically {
            transform = transform.scaledBy(x: 1, y: -1)
        }
        transform = transform.rotated(by: CGFloat(parameters.degrees * .pi / 180))
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        ciImage = ciImage.transformed(by: transform)
        return try renderer.render(ciImage)
    }

    private func clamp(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }
}
