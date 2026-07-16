import Foundation

public enum OptimizePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case bestQuality
    case balanced
    case smallFile
    case web
    case lossless
    case targetSize
    case metadataOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bestQuality: "Best Quality"
        case .balanced: "Balanced"
        case .smallFile: "Small File"
        case .web: "Web"
        case .lossless: "Lossless"
        case .targetSize: "Target Size"
        case .metadataOnly: "Metadata Only"
        }
    }
}

public enum MetadataPolicy: String, Codable, CaseIterable, Sendable {
    case keepAll
    case removePrivate
    case removeAll
}

public enum ResizeIntent: Codable, Hashable, Sendable {
    case keepOriginal
    case longEdge(Int)
    case exact(PixelSize)
}

public enum TargetSizePriority: String, Codable, CaseIterable, Sendable {
    case automatic
    case preserveQuality
    case preserveResolution
}

public struct OptimizeParameters: Codable, Hashable, Sendable {
    public var preset: OptimizePreset
    public var format: ImageFormat
    public var quality: Double
    public var resize: ResizeIntent
    public var metadataPolicy: MetadataPolicy
    public var targetBytes: Int?
    public var targetPriority: TargetSizePriority

    public init(
        preset: OptimizePreset = .balanced,
        format: ImageFormat = .automatic,
        quality: Double = 0.82,
        resize: ResizeIntent = .keepOriginal,
        metadataPolicy: MetadataPolicy = .removePrivate,
        targetBytes: Int? = nil,
        targetPriority: TargetSizePriority = .automatic
    ) {
        self.preset = preset
        self.format = format
        self.quality = min(max(quality, 0), 1)
        self.resize = resize
        self.metadataPolicy = metadataPolicy
        self.targetBytes = targetBytes
        self.targetPriority = targetPriority
    }

    public static func parameters(for preset: OptimizePreset) -> OptimizeParameters {
        switch preset {
        case .bestQuality:
            OptimizeParameters(preset: preset, quality: 0.92, metadataPolicy: .removePrivate)
        case .balanced:
            OptimizeParameters(preset: preset, quality: 0.82, metadataPolicy: .removePrivate)
        case .smallFile:
            OptimizeParameters(preset: preset, quality: 0.68, resize: .longEdge(2048), metadataPolicy: .removePrivate)
        case .web:
            OptimizeParameters(preset: preset, format: .webP, quality: 0.78, resize: .longEdge(2560), metadataPolicy: .removePrivate)
        case .lossless:
            OptimizeParameters(preset: preset, format: .png, quality: 1, metadataPolicy: .removePrivate)
        case .targetSize:
            OptimizeParameters(preset: preset, quality: 0.86, metadataPolicy: .removePrivate, targetBytes: 500_000)
        case .metadataOnly:
            OptimizeParameters(preset: preset, quality: 0.95, metadataPolicy: .removePrivate)
        }
    }
}

public struct OptimizeResult: Sendable {
    public let sourceBytes: Int
    public let outputBytes: Int
    public let format: ImageFormat
    public let pixelSize: PixelSize
    public let quality: Double
    public let data: Data

    public var savedBytes: Int { sourceBytes - outputBytes }
    public var savingsFraction: Double {
        guard sourceBytes > 0 else { return 0 }
        return Double(savedBytes) / Double(sourceBytes)
    }
}
