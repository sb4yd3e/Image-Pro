import CoreGraphics
import XCTest
@testable import ImageProCore

final class ImageFormatClassifierTests: XCTestCase {
    func testTransparentImageUsesPNG() throws {
        let image = try makeImage(alpha: true) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        XCTAssertEqual(ImageFormatClassifier.suggestedFormat(for: image), .png)
    }

    func testFlatGraphicUsesPNG() throws {
        let image = try makeImage(alpha: false) { context in
            context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 12, y: 12, width: 40, height: 20))
        }
        XCTAssertEqual(ImageFormatClassifier.suggestedFormat(for: image), .png)
    }

    func testHighDetailImageUsesJPEG() throws {
        let image = try makeImage(alpha: false) { context in
            for y in 0..<64 {
                for x in 0..<64 {
                    let red = CGFloat(x * 4) / 255
                    let green = CGFloat(y * 4) / 255
                    let blue = CGFloat(((x * 7 + y * 11) % 64) * 4) / 255
                    context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        XCTAssertEqual(ImageFormatClassifier.suggestedFormat(for: image), .jpeg)
    }

    private func makeImage(alpha: Bool, draw: (CGContext) -> Void) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 64,
            height: 64,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue
        ) else {
            throw ImageProcessingError.invalidImage
        }
        draw(context)
        guard let image = context.makeImage() else { throw ImageProcessingError.invalidImage }
        return image
    }
}
