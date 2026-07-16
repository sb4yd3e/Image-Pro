import CoreGraphics
import XCTest
@testable import ImageProCore

final class MaskDocumentTests: XCTestCase {
    func testSubtractiveOnlyStrokeIsNotAUsableMask() {
        let subtractive = MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.2, paintsMask: false)
        ])
        XCTAssertFalse(subtractive.isEmpty)
        XCTAssertFalse(subtractive.hasPaintedContent)

        let additive = MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.2, paintsMask: true)
        ])
        XCTAssertTrue(additive.hasPaintedContent)
    }

    func testRefinementStrokesCanKeepAndRemoveFromExistingMask() throws {
        let black = try grayscaleImage(value: 0, size: 64)
        let keep = MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.25, paintsMask: true)
        ])
        let kept = try keep.rasterized(width: 64, height: 64, base: black)
        XCTAssertGreaterThan(try grayscaleValue(kept, x: 32, y: 32), 200)
        XCTAssertLessThan(try grayscaleValue(kept, x: 2, y: 2), 20)

        let white = try grayscaleImage(value: 255, size: 64)
        let remove = MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.25, paintsMask: false)
        ])
        let removed = try remove.rasterized(width: 64, height: 64, base: white)
        XCTAssertLessThan(try grayscaleValue(removed, x: 32, y: 32), 20)
        XCTAssertGreaterThan(try grayscaleValue(removed, x: 2, y: 2), 200)
    }

    func testStrokeRasterAndContextPlanning() throws {
        let document = MaskDocument(strokes: [
            MaskStroke(
                points: [MaskPoint(x: 0.45, y: 0.5), MaskPoint(x: 0.55, y: 0.5)],
                diameter: 0.1
            )
        ])
        let mask = try document.rasterized(width: 400, height: 300)
        let rect = try ContextCropPlanner.contextRect(
            mask: mask,
            imageSize: PixelSize(width: 400, height: 300)
        )

        XCTAssertGreaterThan(rect.width, 40)
        XCTAssertEqual(rect.width, 256, accuracy: 1)
        XCTAssertEqual(rect.height, 256, accuracy: 1)
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, 400)
        XCTAssertLessThanOrEqual(rect.maxY, 300)
        XCTAssertTrue(rect.contains(CGPoint(x: 200, y: 150)))
    }

    func testUndoAndEraseStroke() throws {
        var document = MaskDocument()
        document.append(MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.2))
        document.append(MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.05, paintsMask: false))
        XCTAssertEqual(document.strokes.count, 2)
        document.undo()
        XCTAssertEqual(document.strokes.count, 1)
        document.clear()
        XCTAssertTrue(document.isEmpty)
    }
}

private func grayscaleImage(value: UInt8, size: Int) throws -> CGImage {
    let bytes = [UInt8](repeating: value, count: size * size)
    guard
        let provider = CGDataProvider(data: Data(bytes) as CFData),
        let image = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else { throw ImageProcessingError.renderFailed }
    return image
}

private func grayscaleValue(_ image: CGImage, x: Int, y: Int) throws -> UInt8 {
    let bytes = try CoreMLModelSupport.rgbaBytes(from: image, width: image.width, height: image.height)
    return bytes[(y * image.width + x) * 4]
}
