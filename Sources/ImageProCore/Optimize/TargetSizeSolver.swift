import Foundation

public struct TargetSizeCandidate: Sendable {
    public let quality: Double
    public let data: Data
    public let meetsTarget: Bool
}

public enum TargetSizeSolver {
    public static func solve(
        targetBytes: Int,
        qualityRange: ClosedRange<Double> = 0.35...0.95,
        iterations: Int = 9,
        encode: (Double) throws -> Data
    ) throws -> TargetSizeCandidate {
        precondition(targetBytes > 0)
        var low = qualityRange.lowerBound
        var high = qualityRange.upperBound
        var bestUnder: TargetSizeCandidate?
        var smallest: TargetSizeCandidate?

        for quality in [low, high] {
            let data = try encode(quality)
            let candidate = TargetSizeCandidate(quality: quality, data: data, meetsTarget: data.count <= targetBytes)
            if candidate.meetsTarget, bestUnder == nil || quality > bestUnder!.quality {
                bestUnder = candidate
            }
            if smallest == nil || data.count < smallest!.data.count {
                smallest = candidate
            }
        }

        for _ in 0..<max(1, iterations) {
            let quality = (low + high) / 2
            let data = try encode(quality)
            let candidate = TargetSizeCandidate(quality: quality, data: data, meetsTarget: data.count <= targetBytes)
            if candidate.meetsTarget {
                bestUnder = candidate
                low = quality
            } else {
                high = quality
            }
            if smallest == nil || data.count < smallest!.data.count {
                smallest = candidate
            }
        }
        return bestUnder ?? smallest!
    }
}
