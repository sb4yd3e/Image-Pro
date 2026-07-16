import CoreGraphics
import XCTest
@testable import ImageProCore

final class OutpaintCanvasBuilderTests: XCTestCase {
    func testRightExpansionAddsRequestedWidth() throws {
        let source = try image(width: 100, height: 80)
        let result = try OutpaintCanvasBuilder.build(image: source, direction: .right, fraction: 0.5)
        XCTAssertEqual(result.image.width, 150)
        XCTAssertEqual(result.image.height, 80)
        XCTAssertEqual(result.originalRect, CGRect(x: 0, y: 0, width: 100, height: 80))
    }

    func testAllExpansionAddsEverySide() throws {
        let source = try image(width: 100, height: 80)
        let result = try OutpaintCanvasBuilder.build(image: source, direction: .all, fraction: 0.25)
        XCTAssertEqual(result.image.width, 150)
        XCTAssertEqual(result.image.height, 120)
        XCTAssertEqual(result.originalRect.origin, CGPoint(x: 25, y: 20))
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw ImageProcessingError.invalidImage
        }
        return image
    }
}
