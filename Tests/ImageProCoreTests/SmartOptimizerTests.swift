import CoreGraphics
import Foundation
import XCTest
@testable import ImageProCore

final class SmartOptimizerTests: XCTestCase {
    func testOptimizeJPEGAndResize() throws {
        let source = try makeJPEG(size: PixelSize(width: 640, height: 480), quality: 0.98)
        let parameters = OptimizeParameters(
            format: .jpeg,
            quality: 0.7,
            resize: .longEdge(320),
            metadataPolicy: .removeAll
        )

        let result = try SmartOptimizer().optimize(data: source, parameters: parameters)
        let decoded = try ImageIOService.decode(data: result.data)

        XCTAssertEqual(result.pixelSize, PixelSize(width: 320, height: 240))
        XCTAssertEqual(decoded.pixelSize, result.pixelSize)
        XCTAssertEqual(result.format, .jpeg)
        XCTAssertGreaterThan(result.outputBytes, 0)
    }

    func testTargetSizeIsRespected() throws {
        let source = try makeJPEG(size: PixelSize(width: 800, height: 600), quality: 1)
        let parameters = OptimizeParameters(
            preset: .targetSize,
            format: .jpeg,
            quality: 0.9,
            metadataPolicy: .removeAll,
            targetBytes: 12_000
        )
        let result = try SmartOptimizer().optimize(data: source, parameters: parameters)
        XCTAssertLessThanOrEqual(result.outputBytes, 12_000)
    }

    private func makeJPEG(size: PixelSize, quality: Double) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ImageProcessingError.invalidImage
        }
        context.setFillColor(CGColor(red: 0.84, green: 0.18, blue: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 30, y: 30, width: size.width / 2, height: size.height / 2))
        guard let image = context.makeImage() else { throw ImageProcessingError.invalidImage }
        return try ImageIOService.encode(
            image: image,
            format: .jpeg,
            quality: quality,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
    }
}
