import CoreGraphics
import Foundation
import XCTest
@testable import ImageProCore

final class BatchOptimizerIntegrationTests: XCTestCase {
    func testBatchAutoFormatWritesValidOutputAndIsolatesInvalidInput() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let output = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let valid = root.appendingPathComponent("photo.jpg")
        let invalid = root.appendingPathComponent("broken.jpg")
        let source = try noisyImage(width: 192, height: 128)
        let sourceData = try ImageEncoderService.encode(
            image: source,
            format: .jpeg,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        try sourceData.write(to: valid)
        try Data("not an image".utf8).write(to: invalid)

        let results = BatchOptimizer().run(
            inputs: [valid, invalid],
            outputDirectory: output,
            parameters: OptimizeParameters(format: .automatic, quality: 0.45)
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].succeeded)
        XCTAssertEqual(results[0].outputURL?.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].outputURL!.path))
        XCTAssertFalse(results[1].succeeded)
        XCTAssertNotNil(results[1].errorDescription)
    }

    func testBatchPreservesFolderStructure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("album/day-one", isDirectory: true)
        let output = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let input = nested.appendingPathComponent("photo.jpg")
        let data = try ImageEncoderService.encode(
            image: noisyImage(width: 192, height: 128),
            format: .jpeg,
            quality: 1,
            sourceProperties: [:],
            metadataPolicy: .removeAll
        )
        try data.write(to: input)

        let results = BatchOptimizer().run(
            inputs: [input],
            outputDirectory: output,
            parameters: OptimizeParameters(format: .jpeg, quality: 0.45),
            recipe: BatchRecipeOptions(
                preserveFolderStructure: true,
                sourceRoot: root
            )
        )

        XCTAssertTrue(results[0].succeeded)
        XCTAssertEqual(
            results[0].outputURL?.deletingLastPathComponent().path,
            output.appendingPathComponent("album/day-one").path
        )
    }

    func testBatchAutoRemoveBackgroundStillAppliesResizeRecipe() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let input = repository.appendingPathComponent("design/image-pro-editor-mockup.png")
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: output) }

        let results = BatchOptimizer().run(
            inputs: [input],
            outputDirectory: output,
            parameters: OptimizeParameters(
                format: .automatic,
                quality: 0.82,
                resize: .longEdge(800)
            ),
            recipe: BatchRecipeOptions(autoRemoveBackground: true)
        )

        XCTAssertTrue(results[0].succeeded, results[0].errorDescription ?? "Batch failed")
        XCTAssertEqual(
            results[0].result.map { max($0.pixelSize.width, $0.pixelSize.height) },
            800
        )
        XCTAssertEqual(results[0].outputURL?.pathExtension, "png")
    }

    private func noisyImage(width: Int, height: Int) throws -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 7
        for index in 0..<(width * height) {
            state = 1_664_525 &* state &+ 1_013_904_223
            bytes[index * 4] = UInt8(truncatingIfNeeded: state >> 8)
            bytes[index * 4 + 1] = UInt8(truncatingIfNeeded: state >> 16)
            bytes[index * 4 + 2] = UInt8(truncatingIfNeeded: state >> 24)
        }
        guard
            let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else { throw ImageProcessingError.invalidImage }
        return image
    }
}
