import Foundation
import UniformTypeIdentifiers

public enum ImageFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case jpeg
    case png
    case heic
    case webP
    case avif
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: "Auto"
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .heic: "HEIC"
        case .webP: "WebP"
        case .avif: "AVIF"
        case .tiff: "TIFF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .automatic, .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .webP: "webp"
        case .avif: "avif"
        case .tiff: "tiff"
        }
    }

    public var typeIdentifier: String {
        switch self {
        case .automatic, .jpeg: UTType.jpeg.identifier
        case .png: UTType.png.identifier
        case .heic: UTType.heic.identifier
        case .webP: UTType.webP.identifier
        case .avif: "public.avif"
        case .tiff: UTType.tiff.identifier
        }
    }

    public var isLossy: Bool {
        switch self {
        case .jpeg, .heic, .webP, .avif, .automatic: true
        case .png, .tiff: false
        }
    }
}
