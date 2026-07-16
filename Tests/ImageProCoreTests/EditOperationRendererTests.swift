import CoreGraphics
import XCTest
@testable import ImageProCore

final class EditOperationRendererTests: XCTestCase {
    func testCropUsesNormalizedTopLeftCoordinates() throws {
        let image = try makeImage(width: 400, height: 300)
        let operation = EditOperation.crop(CropParameters(
            normalizedX: 0.25,
            normalizedY: 0.25,
            normalizedWidth: 0.5,
            normalizedHeight: 0.5
        ))
        let output = try EditOperationRenderer().render(image, operations: [operation])
        XCTAssertEqual(output.width, 200)
        XCTAssertEqual(output.height, 150)
    }

    func testFitAndFillDimensions() throws {
        let image = try makeImage(width: 400, height: 300)
        let renderer = EditOperationRenderer()
        let fitted = try renderer.render(image, operations: [
            .resize(ResizeParameters(size: PixelSize(width: 200, height: 200), mode: .fit))
        ])
        XCTAssertEqual(PixelSize(width: fitted.width, height: fitted.height), PixelSize(width: 200, height: 150))

        let filled = try renderer.render(image, operations: [
            .resize(ResizeParameters(size: PixelSize(width: 200, height: 200), mode: .fill))
        ])
        XCTAssertEqual(PixelSize(width: filled.width, height: filled.height), PixelSize(width: 200, height: 200))
    }

    func testQuarterTurnSwapsDimensions() throws {
        let image = try makeImage(width: 400, height: 300)
        let output = try EditOperationRenderer().render(image, operations: [
            .rotate(RotationParameters(degrees: 90))
        ])
        XCTAssertEqual(output.width, 300)
        XCTAssertEqual(output.height, 400)
    }

    func testCropAtExtremeEdgeStaysInsideImage() throws {
        let image = try makeImage(width: 400, height: 300)
        let output = try EditOperationRenderer().render(image, operations: [
            .crop(CropParameters(
                normalizedX: 1.5,
                normalizedY: 2,
                normalizedWidth: 0.5,
                normalizedHeight: 0.5
            ))
        ])
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
    }

    func testSequentialCropResizeAndRotate() throws {
        let image = try makeImage(width: 400, height: 300)
        let output = try EditOperationRenderer().render(image, operations: [
            .crop(CropParameters(normalizedX: 0.1, normalizedY: 0.1, normalizedWidth: 0.5, normalizedHeight: 0.5)),
            .resize(ResizeParameters(size: PixelSize(width: 120, height: 80), mode: .stretch)),
            .rotate(RotationParameters(degrees: 90, flippedHorizontally: true))
        ])
        XCTAssertEqual(PixelSize(width: output.width, height: output.height), PixelSize(width: 80, height: 120))
    }

    private func makeImage(width: Int, height: Int) throws -> CGImage {
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
