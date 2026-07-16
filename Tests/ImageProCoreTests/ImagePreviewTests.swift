import CoreGraphics
import Foundation
import XCTest
@testable import ImageProCore

final class ImagePreviewTests: XCTestCase {
    func testLargeImagePreviewIsBoundedWithoutChangingFullResolutionData() throws {
        let width = 6_000
        let height = 4_000
        let image = try solidImage(width: width, height: height)
        let data = try ImageEncoderService.encode(
            image: image,
            format: .jpeg,
            quality: 0.8,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )

        let info = try ImageIOService.inspect(data: data)
        let preview = try ImageIOService.preview(data: data, maxPixelDimension: 1_024)
        let full = try ImageIOService.decode(data: data)

        XCTAssertEqual(info.pixelSize, PixelSize(width: width, height: height))
        XCTAssertLessThanOrEqual(max(preview.width, preview.height), 1_024)
        XCTAssertEqual(full.pixelSize, info.pixelSize)
    }

    func testFolderAuditReportsValidImagesAndIgnoresNonImages() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let image = try solidImage(width: 320, height: 200)
        let data = try ImageEncoderService.encode(
            image: image,
            format: .png,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        try data.write(to: root.appendingPathComponent("fixture.png"))
        try Data("not an image".utf8).write(to: root.appendingPathComponent("notes.txt"))

        let report = ImageFolderAuditor.audit(directory: root, previewMaxDimension: 128)

        XCTAssertEqual(report.total, 1)
        XCTAssertEqual(report.passed, 1)
        XCTAssertEqual(report.failed, 0)
        XCTAssertEqual(report.records.first?.width, 320)
        XCTAssertLessThanOrEqual(report.records.first?.previewWidth ?? .max, 128)
    }

    private func solidImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageProcessingError.renderFailed
        }
        context.setFillColor(CGColor(red: 0.12, green: 0.35, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return image
    }
}
