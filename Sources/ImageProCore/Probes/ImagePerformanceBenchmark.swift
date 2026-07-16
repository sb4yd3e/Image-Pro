import Darwin.Mach
import Foundation

public struct ImagePerformanceBenchmarkReport: Codable, Sendable {
    public var generatedAt: Date
    public var path: String
    public var sourceBytes: Int
    public var width: Int
    public var height: Int
    public var inspectMilliseconds: Double
    public var previewMilliseconds: Double
    public var decodeMilliseconds: Double
    public var optimizeMilliseconds: Double
    public var residentMemoryBytes: UInt64
    public var peakResidentMemoryBytes: UInt64
}

public enum ImagePerformanceBenchmark {
    public static func run(file: URL) throws -> ImagePerformanceBenchmarkReport {
        let data = try Data(contentsOf: file, options: .mappedIfSafe)

        let inspectStart = ContinuousClock.now
        let info = try ImageIOService.inspect(data: data)
        let inspectTime = inspectStart.duration(to: .now)

        let previewStart = ContinuousClock.now
        _ = try ImageIOService.preview(data: data)
        let previewTime = previewStart.duration(to: .now)

        let decodeStart = ContinuousClock.now
        _ = try ImageIOService.decode(data: data)
        let decodeTime = decodeStart.duration(to: .now)

        let optimizeStart = ContinuousClock.now
        _ = try SmartOptimizer().optimize(
            data: data,
            parameters: OptimizeParameters(
                preset: .balanced,
                format: .jpeg,
                quality: 0.82,
                resize: .keepOriginal,
                metadataPolicy: .removePrivate
            )
        )
        let optimizeTime = optimizeStart.duration(to: .now)

        return ImagePerformanceBenchmarkReport(
            generatedAt: Date(),
            path: file.path,
            sourceBytes: data.count,
            width: info.pixelSize.width,
            height: info.pixelSize.height,
            inspectMilliseconds: milliseconds(inspectTime),
            previewMilliseconds: milliseconds(previewTime),
            decodeMilliseconds: milliseconds(decodeTime),
            optimizeMilliseconds: milliseconds(optimizeTime),
            residentMemoryBytes: residentMemoryBytes(),
            peakResidentMemoryBytes: peakResidentMemoryBytes()
        )
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func residentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    private static func peakResidentMemoryBytes() -> UInt64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return UInt64(max(usage.ru_maxrss, 0))
    }
}
