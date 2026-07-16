import CoreGraphics
import Foundation
import XCTest
@testable import ImageProCore

final class WebPEncoderTests: XCTestCase {
    func testEncoderVersionAndCapability() {
        XCTAssertFalse(WebPEncoder.version.isEmpty)
        XCTAssertTrue(ImageEncoderService.supports(.webP))
    }

    func testLossyWebPRoundTrip() throws {
        let image = try makeImage(width: 320, height: 240, alpha: 255)
        let data = try WebPEncoder.encode(image: image, quality: 0.8)

        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.dropFirst(8).prefix(4), encoding: .ascii), "WEBP")

        let decoded = try ImageIOService.decode(data: data)
        XCTAssertEqual(decoded.pixelSize, PixelSize(width: 320, height: 240))
    }

    func testLosslessWebPPreservesAlphaChannel() throws {
        let image = try makeImage(width: 64, height: 64, alpha: 128)
        let data = try WebPEncoder.encode(image: image, quality: 1, lossless: true)
        let decoded = try ImageIOService.decode(data: data)

        XCTAssertTrue(ImageIOService.hasAlpha(decoded.image))
        XCTAssertEqual(decoded.pixelSize, PixelSize(width: 64, height: 64))
    }

    func testSmartOptimizerOutputsWebP() throws {
        let image = try makeImage(width: 400, height: 300, alpha: 255)
        let png = try ImageIOService.encode(
            image: image,
            format: .png,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        let result = try SmartOptimizer().optimize(
            data: png,
            parameters: OptimizeParameters(preset: .web, format: .webP, quality: 0.76)
        )

        XCTAssertEqual(result.format, .webP)
        XCTAssertEqual(String(data: result.data.dropFirst(8).prefix(4), encoding: .ascii), "WEBP")
        XCTAssertEqual(try ImageIOService.decode(data: result.data).pixelSize, PixelSize(width: 400, height: 300))
    }

    func testWebPTargetSize() throws {
        let image = try makeImage(width: 800, height: 600, alpha: 255)
        let png = try ImageIOService.encode(
            image: image,
            format: .png,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        let result = try SmartOptimizer().optimize(
            data: png,
            parameters: OptimizeParameters(
                preset: .targetSize,
                format: .webP,
                quality: 0.85,
                metadataPolicy: .removeAll,
                targetBytes: 8_000
            )
        )

        XCTAssertLessThanOrEqual(result.outputBytes, 8_000)
        XCTAssertEqual(result.format, .webP)
    }

    private func makeImage(width: Int, height: Int, alpha: UInt8) throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                pixels[offset] = UInt8((x * 255) / max(1, width - 1))
                pixels[offset + 1] = UInt8((y * 255) / max(1, height - 1))
                pixels[offset + 2] = UInt8((x + y) % 256)
                pixels[offset + 3] = alpha
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData), let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw ImageProcessingError.invalidImage
        }
        return image
    }
}
