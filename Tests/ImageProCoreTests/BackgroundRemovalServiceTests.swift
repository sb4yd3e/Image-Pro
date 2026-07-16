import CoreGraphics
import CoreVideo
import XCTest
@testable import ImageProCore

final class BackgroundRemovalServiceTests: XCTestCase {
    func testTransparentReplacementProducesTransparentPixelForEmptyMask() throws {
        let source = try solidImage(width: 8, height: 8, red: 1, green: 0, blue: 0)
        let output = try BackgroundRemovalService(provider: EmptyMaskProvider()).removeBackground(
            from: source,
            edge: BackgroundEdgeConfiguration(featherRadius: 0),
            replacement: .transparent
        )
        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 8)
        XCTAssertEqual(try rgbaPixel(output)[3], 0)
    }

    func testSolidReplacementIsOpaqueForEmptyMask() throws {
        let source = try solidImage(width: 8, height: 8, red: 1, green: 0, blue: 0)
        let output = try BackgroundRemovalService(provider: EmptyMaskProvider()).removeBackground(
            from: source,
            edge: BackgroundEdgeConfiguration(featherRadius: 0),
            replacement: .solid(red: 1, green: 1, blue: 1)
        )
        let pixel = try rgbaPixel(output)
        XCTAssertGreaterThan(pixel[0], 245)
        XCTAssertGreaterThan(pixel[1], 245)
        XCTAssertGreaterThan(pixel[2], 245)
        XCTAssertEqual(pixel[3], 255)
    }

    private func solidImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.invalidImage }
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw ImageProcessingError.invalidImage }
        return image
    }

    private func rgbaPixel(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.invalidImage }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }
}

private final class EmptyMaskProvider: ForegroundMaskProviding {
    func mask(for image: CGImage, instances: IndexSet) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw ImageProcessingError.renderFailed
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
