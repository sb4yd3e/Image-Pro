import CoreGraphics
import Foundation

public enum ImageFormatClassifier {
    public static func suggestedFormat(for image: CGImage) -> ImageFormat {
        if ImageIOService.hasAlpha(image) {
            return .png
        }

        let width = min(64, image.width)
        let height = min(64, image.height)
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return .jpeg
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var quantizedColors = Set<UInt16>()
        var flatNeighborCount = 0
        var neighborCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let red = pixels[offset]
                let green = pixels[offset + 1]
                let blue = pixels[offset + 2]
                let color = (UInt16(red >> 3) << 10) | (UInt16(green >> 3) << 5) | UInt16(blue >> 3)
                quantizedColors.insert(color)

                if x > 0 {
                    neighborCount += 1
                    let previous = offset - 4
                    let delta = abs(Int(red) - Int(pixels[previous]))
                        + abs(Int(green) - Int(pixels[previous + 1]))
                        + abs(Int(blue) - Int(pixels[previous + 2]))
                    if delta < 18 { flatNeighborCount += 1 }
                }
            }
        }

        let flatRatio = Double(flatNeighborCount) / Double(max(1, neighborCount))
        return quantizedColors.count < 420 || flatRatio > 0.58 ? .png : .jpeg
    }
}
