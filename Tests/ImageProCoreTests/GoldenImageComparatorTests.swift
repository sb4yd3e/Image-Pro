import CoreGraphics
import XCTest
@testable import ImageProCore

final class GoldenImageComparatorTests: XCTestCase {
    func testIdenticalImagesPass() throws {
        let image = try solidImage(red: 30)
        let report = try GoldenImageComparator.compare(actual: image, baseline: image)
        XCTAssertTrue(report.passed)
        XCTAssertEqual(report.changedPixelRatio, 0)
    }

    func testVisibleDifferenceFails() throws {
        let actual = try solidImage(red: 220)
        let baseline = try solidImage(red: 20)
        let report = try GoldenImageComparator.compare(actual: actual, baseline: baseline)
        XCTAssertFalse(report.passed)
        XCTAssertEqual(report.changedPixelRatio, 1)
        XCTAssertGreaterThan(report.maximumChannelDifference, 100)
    }

    private func solidImage(red: UInt8) throws -> CGImage {
        let color = CGFloat(red) / 255
        guard let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.renderFailed }
        context.setFillColor(CGColor(red: color, green: 0.2, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        guard let image = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return image
    }
}
