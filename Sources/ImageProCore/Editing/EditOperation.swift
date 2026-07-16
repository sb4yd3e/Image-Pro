import Foundation

public struct CropParameters: Codable, Hashable, Sendable {
    public var normalizedX: Double
    public var normalizedY: Double
    public var normalizedWidth: Double
    public var normalizedHeight: Double

    public init(normalizedX: Double, normalizedY: Double, normalizedWidth: Double, normalizedHeight: Double) {
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.normalizedWidth = normalizedWidth
        self.normalizedHeight = normalizedHeight
    }
}

public struct ResizeParameters: Codable, Hashable, Sendable {
    public var size: PixelSize
    public var mode: ResizeMode

    public init(size: PixelSize, mode: ResizeMode = .fit) {
        self.size = size
        self.mode = mode
    }
}

public enum ResizeMode: String, Codable, Hashable, Sendable {
    case fit
    case fill
    case stretch
}

public struct RotationParameters: Codable, Hashable, Sendable {
    public var degrees: Double
    public var flippedHorizontally: Bool
    public var flippedVertically: Bool

    public init(degrees: Double, flippedHorizontally: Bool = false, flippedVertically: Bool = false) {
        self.degrees = degrees
        self.flippedHorizontally = flippedHorizontally
        self.flippedVertically = flippedVertically
    }
}

public struct AssetReference: Codable, Hashable, Sendable {
    public var relativePath: String
    public var sha256: String

    public init(relativePath: String, sha256: String) {
        self.relativePath = relativePath
        self.sha256 = sha256
    }
}

public enum EditOperation: Codable, Hashable, Sendable {
    case crop(CropParameters)
    case resize(ResizeParameters)
    case rotate(RotationParameters)
    case backgroundMask(AssetReference)
    case inpaint(render: AssetReference, mask: AssetReference)
    case upscale(render: AssetReference, scale: Int)
    case optimizePreview(OptimizeParameters)
}
