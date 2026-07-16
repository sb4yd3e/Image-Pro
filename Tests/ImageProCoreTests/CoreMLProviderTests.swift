import CoreGraphics
import Foundation
import XCTest
@testable import ImageProCore

final class CoreMLProviderTests: XCTestCase {
    func testLaMaProviderProducesOriginalDimensions() throws {
        let provider = try LaMaInpaintingProvider(modelURL: modelURL("LaMa"))
        let image = try makeImage(width: 256, height: 192)
        let mask = try MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.2)
        ]).rasterized(width: 256, height: 192)

        let output = try provider.inpaint(image: image, mask: mask)
        XCTAssertEqual(output.width, 256)
        XCTAssertEqual(output.height, 192)
        let originalBytes = try CoreMLModelSupport.rgbaBytes(from: image, width: 256, height: 192)
        let outputBytes = try CoreMLModelSupport.rgbaBytes(from: output, width: 256, height: 192)
        XCTAssertEqual(Array(originalBytes[0..<4]), Array(outputBytes[0..<4]), "Pixels far outside the mask must remain unchanged")
    }

    @available(macOS 15.0, *)
    func testRealESRGANProviderProducesFourTimesDimensions() throws {
        let provider = try RealESRGANProvider(modelURL: modelURL("RealESRGAN-x4plus"))
        let image = try makeImage(width: 48, height: 32)
        let output = try provider.upscale(image)
        XCTAssertEqual(output.width, 192)
        XCTAssertEqual(output.height, 128)
    }

    @available(macOS 15.0, *)
    func testRealESRGANProviderSupportsTwoTimesOutput() throws {
        let provider = try RealESRGANProvider(modelURL: modelURL("RealESRGAN-x4plus"))
        let image = try makeImage(width: 32, height: 24)
        let output = try provider.upscale(image, scale: 2)
        XCTAssertEqual(output.width, 64)
        XCTAssertEqual(output.height, 48)
    }

    @available(macOS 15.0, *)
    func testRealESRGANProviderPreservesTransparentBackground() throws {
        let provider = try RealESRGANProvider(modelURL: modelURL("RealESRGAN-x4plus"))
        let image = try makeAlphaImage(width: 32, height: 24)
        let output = try provider.upscale(image, scale: 2)
        let bytes = try CoreMLModelSupport.rgbaBytes(from: output, width: 64, height: 48)
        XCTAssertLessThan(bytes[3], 8)
        let centerAlpha = bytes[((24 * 64 + 32) * 4) + 3]
        XCTAssertGreaterThan(centerAlpha, 245)
    }

    @available(macOS 15.0, *)
    func testRealESRGANShortTileDoesNotReplaceImageWithClampedEdgeBands() throws {
        let provider = try RealESRGANProvider(modelURL: modelURL("RealESRGAN-x4plus"))
        let image = try makeBandImage(width: 40, height: 32)
        let output = try provider.upscale(image, scale: 2)
        let bytes = try CoreMLModelSupport.rgbaBytes(from: output, width: 80, height: 64)
        let top = (8 * 80 + 40) * 4
        let bottom = (56 * 80 + 40) * 4
        XCTAssertGreaterThan(bytes[top], bytes[top + 2], "Top red band should remain at the top")
        XCTAssertGreaterThan(bytes[bottom + 2], bytes[bottom], "Bottom blue band should remain at the bottom")
    }

    @available(macOS 14.0, *)
    func testStableDiffusionGenerativeFillProducesOriginalDimensions() throws {
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Models/Optional/StableDiffusion", isDirectory: true)
        guard FileManager.default.fileExists(atPath: resources.path) else {
            throw XCTSkip("Optional Stable Diffusion resources are not installed")
        }

        let image = try makeImage(width: 96, height: 72)
        let mask = try MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.25)
        ]).rasterized(width: 96, height: 72)
        let provider = StableDiffusionGenerativeProvider(resourcesURL: resources)
        let output = try provider.fill(
            image: image,
            mask: mask,
            configuration: GenerativeFillConfiguration(
                prompt: "a small red flower",
                seed: 7,
                strength: 0.75,
                stepCount: 2,
                variantCount: 1
            )
        )

        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output[0].width, 96)
        XCTAssertEqual(output[0].height, 72)
        let originalBytes = try CoreMLModelSupport.rgbaBytes(from: image, width: 96, height: 72)
        let outputBytes = try CoreMLModelSupport.rgbaBytes(from: output[0], width: 96, height: 72)
        XCTAssertEqual(Array(originalBytes[0..<4]), Array(outputBytes[0..<4]), "Generative composite must preserve pixels outside the mask")
    }

    private func modelURL(_ name: String) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Models/Bundled/\(name).mlpackage")
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
        ) else {
            throw ImageProcessingError.invalidImage
        }
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1),
                CGColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1)
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: width, y: height),
            options: []
        )
        guard let image = context.makeImage() else { throw ImageProcessingError.invalidImage }
        return image
    }

    private func makeAlphaImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.invalidImage }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1))
        context.fillEllipse(in: CGRect(x: 8, y: 4, width: 16, height: 16))
        guard let image = context.makeImage() else { throw ImageProcessingError.invalidImage }
        return image
    }

    private func makeBandImage(width: Int, height: Int) throws -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                bytes[offset] = y < height / 2 ? 230 : 20
                bytes[offset + 1] = 25
                bytes[offset + 2] = y < height / 2 ? 20 : 230
            }
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
