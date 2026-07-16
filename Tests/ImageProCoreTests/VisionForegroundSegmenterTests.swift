import Foundation
import CoreGraphics
import CoreImage
import XCTest
@testable import ImageProCore

@available(macOS 14.0, *)
final class VisionForegroundSegmenterTests: XCTestCase {
    func testNoForegroundErrorHasActionableDescription() {
        let message = VisionForegroundError.noForegroundFound.localizedDescription
        XCTAssertTrue(message.contains("No clear foreground subject"))
        XCTAssertFalse(message.contains("error 0"))
    }

    func testFlatPosterKeepsCardAndRemovesEdgeBackground() throws {
        let width = 320
        let height = 400
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.renderFailed }
        context.setFillColor(CGColor(red: 0.88, green: 0.04, blue: 0.02, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 42, y: 85, width: 236, height: 210))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 125, y: 145, width: 70, height: 70))
        guard let poster = context.makeImage() else { throw ImageProcessingError.renderFailed }

        let mask = try VisionForegroundSegmenter().mask(for: poster)
        let rendered = try CoreImageRenderer.shared.render(CIImage(cvPixelBuffer: mask))
        let bytes = try CoreMLModelSupport.rgbaBytes(
            from: rendered,
            width: rendered.width,
            height: rendered.height
        )
        func value(x: Int, y: Int) -> UInt8 {
            bytes[(y * rendered.width + x) * 4]
        }
        XCTAssertLessThan(value(x: 2, y: 2), 80)
        XCTAssertGreaterThan(value(x: rendered.width / 2, y: rendered.height / 2), 160)
    }

    func testDefaultSelectionUsesAllDetectedInstancesAndKeepsVisibleForeground() throws {
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/checkouts/ml-stable-diffusion/assets/a_high_quality_photo_of_an_astronaut_riding_a_horse_in_space/randomSeed_93_computeUnit_CPU_AND_GPU_modelVersion_runwayml_stable-diffusion-v1-5.png")
        guard let data = try? Data(contentsOf: fixture) else {
            throw XCTSkip("Stable Diffusion sample fixture is unavailable")
        }
        let decoded = try ImageIOService.decode(data: data)
        let output = try BackgroundRemovalService(provider: VisionForegroundSegmenter()).removeBackground(
            from: decoded.image,
            edge: BackgroundEdgeConfiguration(featherRadius: 0)
        )
        let bytes = try CoreMLModelSupport.rgbaBytes(from: output, width: 64, height: 64)
        let alpha = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        let visible = alpha.filter { $0 > 16 }.count
        let transparent = alpha.filter { $0 < 240 }.count

        XCTAssertGreaterThan(visible, 64, "Foreground must not disappear")
        XCTAssertGreaterThan(transparent, 64, "Background should become transparent")
    }
}
