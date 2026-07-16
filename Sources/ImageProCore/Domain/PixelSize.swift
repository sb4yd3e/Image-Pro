import Foundation

public struct PixelSize: Codable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    public var pixelCount: Int {
        width.multipliedReportingOverflow(by: height).partialValue
    }

    public var aspectRatio: Double {
        Double(width) / Double(height)
    }

    public func fitting(within bounds: PixelSize, allowUpscale: Bool = false) -> PixelSize {
        var scale = min(
            Double(bounds.width) / Double(width),
            Double(bounds.height) / Double(height)
        )
        if !allowUpscale {
            scale = min(scale, 1)
        }
        return scaled(by: scale)
    }

    public func filling(_ bounds: PixelSize) -> PixelSize {
        let scale = max(
            Double(bounds.width) / Double(width),
            Double(bounds.height) / Double(height)
        )
        return scaled(by: scale)
    }

    public func constrainedTo(longEdge: Int, allowUpscale: Bool = false) -> PixelSize {
        let current = max(width, height)
        guard allowUpscale || longEdge < current else { return self }
        return scaled(by: Double(max(1, longEdge)) / Double(current))
    }

    public func scaled(by scale: Double) -> PixelSize {
        PixelSize(
            width: max(1, Int((Double(width) * scale).rounded())),
            height: max(1, Int((Double(height) * scale).rounded()))
        )
    }
}
