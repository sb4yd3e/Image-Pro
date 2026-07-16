import CoreGraphics
import CoreText
import XCTest
@testable import ImageProCore

final class VisionTextRecognizerTests: XCTestCase {
    func testSupportedLanguagesIncludesEnglish() throws {
        let languages = try VisionTextRecognizer().supportedLanguages()
        XCTAssertTrue(languages.contains { $0.hasPrefix("en") })
    }

    func testRecognizesRenderedEnglishText() throws {
        let image = try textImage("HELLO 123")
        let result = try VisionTextRecognizer().recognize(
            image: image,
            quality: .accurate,
            languages: ["en-US"]
        )
        XCTAssertTrue(result.text.uppercased().contains("HELLO"))
        XCTAssertFalse(result.blocks.isEmpty)
    }

    private func textImage(_ text: String) throws -> CGImage {
        let width = 720
        let height = 180
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.renderFailed }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica-Bold" as CFString, 72, nil),
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: 24, y: 54)
        CTLineDraw(line, context)
        guard let image = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return image
    }
}
