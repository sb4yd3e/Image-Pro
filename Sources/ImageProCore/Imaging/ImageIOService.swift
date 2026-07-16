import CoreGraphics
import Foundation
import ImageIO

public struct DecodedImage {
    public let image: CGImage
    public let sourceProperties: [CFString: Any]
    public let typeIdentifier: String?

    public var pixelSize: PixelSize {
        PixelSize(width: image.width, height: image.height)
    }
}

public struct ImageSourceInfo {
    public let pixelSize: PixelSize
    public let sourceProperties: [CFString: Any]
    public let typeIdentifier: String?
}

public enum ImageIOService {
    public static func inspect(data: Data) throws -> ImageSourceInfo {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageProcessingError.invalidImage
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        guard
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0,
            height > 0
        else {
            throw ImageProcessingError.invalidImage
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let swapsDimensions = (5...8).contains(orientation)
        return ImageSourceInfo(
            pixelSize: PixelSize(
                width: swapsDimensions ? height : width,
                height: swapsDimensions ? width : height
            ),
            sourceProperties: properties,
            typeIdentifier: CGImageSourceGetType(source) as String?
        )
    }

    public static func preview(data: Data, maxPixelDimension: Int = 2_048) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageProcessingError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelDimension),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageProcessingError.invalidImage
        }
        return image
    }

    public static func decode(data: Data) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageProcessingError.invalidImage
        }
        let rawProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = rawProperties[kCGImagePropertyPixelWidth] as? Int ?? 1
        let height = rawProperties[kCGImagePropertyPixelHeight] as? Int ?? 1
        let maxDimension = max(width, height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageProcessingError.invalidImage
        }
        return DecodedImage(
            image: image,
            sourceProperties: rawProperties,
            typeIdentifier: CGImageSourceGetType(source) as String?
        )
    }

    public static func encode(
        image: CGImage,
        format: ImageFormat,
        quality: Double,
        sourceProperties: [CFString: Any],
        metadataPolicy: MetadataPolicy
    ) throws -> Data {
        guard supportedDestinationTypeIdentifiers.contains(format.typeIdentifier) else {
            throw ImageProcessingError.destinationUnsupported(format)
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            format.typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw ImageProcessingError.encodeFailed
        }

        var properties = exportProperties(from: sourceProperties, policy: metadataPolicy)
        if format.isLossy {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        properties[kCGImagePropertyOrientation] = 1

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageProcessingError.encodeFailed
        }
        return output as Data
    }

    public static var supportedSourceTypeIdentifiers: Set<String> {
        Set(CGImageSourceCopyTypeIdentifiers() as? [String] ?? [])
    }

    public static var supportedDestinationTypeIdentifiers: Set<String> {
        Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
    }

    public static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        default:
            true
        }
    }

    public static func exportProperties(
        from source: [CFString: Any],
        policy: MetadataPolicy
    ) -> [CFString: Any] {
        switch policy {
        case .removeAll:
            return [:]
        case .removePrivate:
            var result = source
            result.removeValue(forKey: kCGImagePropertyGPSDictionary)
            result.removeValue(forKey: kCGImagePropertyExifDictionary)
            result.removeValue(forKey: kCGImagePropertyExifAuxDictionary)
            result.removeValue(forKey: kCGImagePropertyIPTCDictionary)
            result.removeValue(forKey: kCGImagePropertyMakerAppleDictionary)
            result.removeValue(forKey: kCGImagePropertyRawDictionary)
            return result
        case .keepAll:
            return source
        }
    }
}
