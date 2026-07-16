import CWebPBridge
import CoreGraphics
import Foundation

public enum WebPEncoder {
    public static var version: String {
        String(cString: imagepro_webp_version())
    }

    public static func encode(
        image: CGImage,
        quality: Double,
        lossless: Bool = false
    ) throws -> Data {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)

        let drewImage = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress else { return false }
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            unpremultiplyRGBA(bytes.bindMemory(to: UInt8.self))
            return true
        }
        guard drewImage else { throw ImageProcessingError.renderFailed }

        var outputPointer: UnsafeMutablePointer<UInt8>?
        var outputSize = 0
        let succeeded = pixels.withUnsafeBytes { bytes in
            imagepro_webp_encode_rgba(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                Int32(width),
                Int32(height),
                Int32(bytesPerRow),
                Float(min(max(quality, 0), 1) * 100),
                lossless ? 1 : 0,
                &outputPointer,
                &outputSize
            )
        }
        guard succeeded == 1, let outputPointer, outputSize > 0 else {
            throw ImageProcessingError.encodeFailed
        }
        defer { imagepro_webp_free(outputPointer) }
        return Data(bytes: outputPointer, count: outputSize)
    }

    private static func unpremultiplyRGBA(_ pixels: UnsafeMutableBufferPointer<UInt8>) {
        guard pixels.count >= 4 else { return }
        for offset in stride(from: 0, to: pixels.count - 3, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            pixels[offset] = UInt8(min(255, Int(pixels[offset]) * 255 / alpha))
            pixels[offset + 1] = UInt8(min(255, Int(pixels[offset + 1]) * 255 / alpha))
            pixels[offset + 2] = UInt8(min(255, Int(pixels[offset + 2]) * 255 / alpha))
        }
    }
}
