import ImageIO
import XCTest
@testable import ImageProCore

final class MetadataPolicyTests: XCTestCase {
    func testRemovePrivateMetadata() {
        let source: [CFString: Any] = [
            kCGImagePropertyPixelWidth: 100,
            kCGImagePropertyGPSDictionary: ["Latitude": 13.7563],
            kCGImagePropertyExifDictionary: ["Camera": "Private Camera"],
            kCGImagePropertyPNGDictionary: ["InterlaceType": 0]
        ]
        let result = ImageIOService.exportProperties(from: source, policy: .removePrivate)
        XCTAssertNil(result[kCGImagePropertyGPSDictionary])
        XCTAssertNil(result[kCGImagePropertyExifDictionary])
        XCTAssertNotNil(result[kCGImagePropertyPNGDictionary])
    }

    func testRemoveAllMetadata() {
        XCTAssertTrue(ImageIOService.exportProperties(from: [kCGImagePropertyPixelWidth: 100], policy: .removeAll).isEmpty)
    }

    func testRemovePrivateMetadataAfterEncodeAndReread() throws {
        let output = try ImageIOService.encode(
            image: makeImage(),
            format: .jpeg,
            quality: 0.9,
            sourceProperties: metadataFixture,
            metadataPolicy: .removePrivate
        )
        let properties = try ImageIOService.decode(data: output).sourceProperties

        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFArtist] as? String, "Image Pro Test")
    }

    func testKeepAllMetadataAfterEncodeAndReread() throws {
        let output = try ImageIOService.encode(
            image: makeImage(),
            format: .jpeg,
            quality: 0.9,
            sourceProperties: metadataFixture,
            metadataPolicy: .keepAll
        )
        let properties = try ImageIOService.decode(data: output).sourceProperties
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]

        let latitude = try XCTUnwrap(gps?[kCGImagePropertyGPSLatitude] as? Double)
        XCTAssertEqual(latitude, 13.7563, accuracy: 0.0001)
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal] as? String, "2026:07:15 10:00:00")
    }

    private var metadataFixture: [CFString: Any] {
        [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 13.7563,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 100.5018,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:07:15 10:00:00"
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFArtist: "Image Pro Test"
            ]
        ]
    }

    private func makeImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 16,
            height: 12,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        return context.makeImage()!
    }
}
