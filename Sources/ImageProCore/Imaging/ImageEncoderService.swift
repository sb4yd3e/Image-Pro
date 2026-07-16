import CoreGraphics
import Foundation

public enum ImageEncoderService {
    public static func supports(_ format: ImageFormat) -> Bool {
        switch format {
        case .automatic:
            true
        case .webP:
            true
        default:
            ImageIOService.supportedDestinationTypeIdentifiers.contains(format.typeIdentifier)
        }
    }

    public static func encode(
        image: CGImage,
        format: ImageFormat,
        quality: Double,
        sourceProperties: [CFString: Any],
        metadataPolicy: MetadataPolicy,
        lossless: Bool = false
    ) throws -> Data {
        if format == .webP {
            return try WebPEncoder.encode(image: image, quality: quality, lossless: lossless)
        }
        return try ImageIOService.encode(
            image: image,
            format: format,
            quality: quality,
            sourceProperties: sourceProperties,
            metadataPolicy: metadataPolicy
        )
    }
}
