import CoreGraphics
import Foundation

public enum OutpaintDirection: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
    case all
}

public struct OutpaintCanvasResult: Sendable {
    public let image: CGImage
    public let mask: CGImage
    public let originalRect: CGRect
}

public enum OutpaintCanvasBuilder {
    public static func build(
        image: CGImage,
        direction: OutpaintDirection,
        fraction requestedFraction: Double
    ) throws -> OutpaintCanvasResult {
        let fraction = min(max(requestedFraction, 0.05), 1)
        let horizontal = max(1, Int((Double(image.width) * fraction).rounded()))
        let vertical = max(1, Int((Double(image.height) * fraction).rounded()))
        let left = direction == .left || direction == .all ? horizontal : 0
        let right = direction == .right || direction == .all ? horizontal : 0
        let top = direction == .top || direction == .all ? vertical : 0
        let bottom = direction == .bottom || direction == .all ? vertical : 0
        let width = image.width + left + right
        let height = image.height + top + bottom
        let originalRect = CGRect(x: left, y: bottom, width: image.width, height: image.height)

        guard let canvas = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CoreMLImageError.allocationFailed }
        canvas.setFillColor(CGColor(gray: 0.5, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
        canvas.draw(image, in: originalRect)

        guard let maskContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw CoreMLImageError.allocationFailed }
        maskContext.setFillColor(gray: 1, alpha: 1)
        maskContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Keep the original while allowing overlap only along newly generated edges.
        let overlap = CGFloat(min(12, max(2, min(image.width, image.height) / 100)))
        maskContext.setFillColor(gray: 0, alpha: 1)
        maskContext.fill(originalRect)
        maskContext.setFillColor(gray: 1, alpha: 1)
        if left > 0 {
            maskContext.fill(CGRect(x: originalRect.minX, y: originalRect.minY, width: overlap, height: originalRect.height))
        }
        if right > 0 {
            maskContext.fill(CGRect(x: originalRect.maxX - overlap, y: originalRect.minY, width: overlap, height: originalRect.height))
        }
        if top > 0 {
            maskContext.fill(CGRect(x: originalRect.minX, y: originalRect.maxY - overlap, width: originalRect.width, height: overlap))
        }
        if bottom > 0 {
            maskContext.fill(CGRect(x: originalRect.minX, y: originalRect.minY, width: originalRect.width, height: overlap))
        }

        guard let output = canvas.makeImage(), let mask = maskContext.makeImage() else {
            throw ImageProcessingError.renderFailed
        }
        return OutpaintCanvasResult(image: output, mask: mask, originalRect: originalRect)
    }
}
