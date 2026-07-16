import CoreGraphics
import Foundation

public struct MaskPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}

public struct MaskStroke: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var points: [MaskPoint]
    public var diameter: Double
    public var paintsMask: Bool

    public init(id: UUID = UUID(), points: [MaskPoint], diameter: Double, paintsMask: Bool = true) {
        self.id = id
        self.points = points
        self.diameter = min(max(diameter, 0.001), 1)
        self.paintsMask = paintsMask
    }
}

public struct MaskDocument: Codable, Hashable, Sendable {
    public var strokes: [MaskStroke]

    public init(strokes: [MaskStroke] = []) {
        self.strokes = strokes
    }

    public var isEmpty: Bool { strokes.isEmpty }

    /// True when the document contains at least one stroke that can create mask pixels.
    /// Subtractive-only strokes are intentionally not considered a usable mask.
    public var hasPaintedContent: Bool {
        strokes.contains { $0.paintsMask && !$0.points.isEmpty }
    }

    public mutating func append(_ stroke: MaskStroke) {
        strokes.append(stroke)
    }

    public mutating func undo() {
        if !strokes.isEmpty { strokes.removeLast() }
    }

    public mutating func clear() {
        strokes.removeAll()
    }

    public func rasterized(width: Int, height: Int, base: CGImage? = nil) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw CoreMLImageError.allocationFailed
        }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if let base {
            context.interpolationQuality = .high
            context.draw(base, in: bounds)
        } else {
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(bounds)
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for stroke in strokes where !stroke.points.isEmpty {
            context.setStrokeColor(gray: stroke.paintsMask ? 1 : 0, alpha: 1)
            context.setFillColor(gray: stroke.paintsMask ? 1 : 0, alpha: 1)
            context.setLineWidth(CGFloat(stroke.diameter) * CGFloat(min(width, height)))
            let points = stroke.points.map {
                CGPoint(x: $0.x * Double(width), y: (1 - $0.y) * Double(height))
            }
            if points.count == 1 {
                let radius = CGFloat(stroke.diameter) * CGFloat(min(width, height)) / 2
                context.fillEllipse(in: CGRect(
                    x: points[0].x - radius,
                    y: points[0].y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            } else {
                context.beginPath()
                context.move(to: points[0])
                for point in points.dropFirst() { context.addLine(to: point) }
                context.strokePath()
            }
        }

        guard let image = context.makeImage() else { throw ImageProcessingError.renderFailed }
        return image
    }
}
