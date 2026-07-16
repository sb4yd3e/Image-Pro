import CoreGraphics
import Foundation

public struct GoldenImageComparisonReport: Codable, Sendable {
    public var actualPath: String?
    public var baselinePath: String?
    public var width: Int
    public var height: Int
    public var dimensionsMatch: Bool
    public var maximumChannelDifference: Int
    public var meanAbsoluteChannelDifference: Double
    public var changedPixelRatio: Double
    public var channelTolerance: Int
    public var changedPixelRatioTolerance: Double
    public var passed: Bool
}

public enum GoldenImageComparator {
    public static func compare(
        actualURL: URL,
        baselineURL: URL,
        channelTolerance: Int = 2,
        changedPixelRatioTolerance: Double = 0.001
    ) throws -> GoldenImageComparisonReport {
        let actual = try ImageIOService.decode(data: Data(contentsOf: actualURL)).image
        let baseline = try ImageIOService.decode(data: Data(contentsOf: baselineURL)).image
        var report = try compare(
            actual: actual,
            baseline: baseline,
            channelTolerance: channelTolerance,
            changedPixelRatioTolerance: changedPixelRatioTolerance
        )
        report.actualPath = actualURL.path
        report.baselinePath = baselineURL.path
        return report
    }

    public static func compare(
        actual: CGImage,
        baseline: CGImage,
        channelTolerance: Int = 2,
        changedPixelRatioTolerance: Double = 0.001
    ) throws -> GoldenImageComparisonReport {
        let dimensionsMatch = actual.width == baseline.width && actual.height == baseline.height
        guard dimensionsMatch else {
            return GoldenImageComparisonReport(
                width: actual.width,
                height: actual.height,
                dimensionsMatch: false,
                maximumChannelDifference: 255,
                meanAbsoluteChannelDifference: 255,
                changedPixelRatio: 1,
                channelTolerance: channelTolerance,
                changedPixelRatioTolerance: changedPixelRatioTolerance,
                passed: false
            )
        }

        let actualBytes = try rgbaBytes(actual)
        let baselineBytes = try rgbaBytes(baseline)
        let pixelCount = actual.width * actual.height
        var maximumDifference = 0
        var totalDifference: UInt64 = 0
        var changedPixels = 0

        for pixel in 0..<pixelCount {
            let offset = pixel * 4
            var pixelChanged = false
            for channel in 0..<4 {
                let difference = abs(Int(actualBytes[offset + channel]) - Int(baselineBytes[offset + channel]))
                maximumDifference = max(maximumDifference, difference)
                totalDifference += UInt64(difference)
                pixelChanged = pixelChanged || difference > channelTolerance
            }
            if pixelChanged { changedPixels += 1 }
        }

        let changedRatio = Double(changedPixels) / Double(max(pixelCount, 1))
        let meanDifference = Double(totalDifference) / Double(max(pixelCount * 4, 1))
        return GoldenImageComparisonReport(
            width: actual.width,
            height: actual.height,
            dimensionsMatch: true,
            maximumChannelDifference: maximumDifference,
            meanAbsoluteChannelDifference: meanDifference,
            changedPixelRatio: changedRatio,
            channelTolerance: channelTolerance,
            changedPixelRatioTolerance: changedPixelRatioTolerance,
            passed: changedRatio <= changedPixelRatioTolerance
        )
    }

    private static func rgbaBytes(_ image: CGImage) throws -> [UInt8] {
        let bytesPerRow = image.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        guard let context = CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageProcessingError.renderFailed }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }
}
