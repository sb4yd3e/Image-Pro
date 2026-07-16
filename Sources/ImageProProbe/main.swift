import Foundation
import ImageProCore

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let data: Data
    if let comparisonIndex = arguments.firstIndex(of: "--compare-images"),
       arguments.indices.contains(comparisonIndex + 2) {
        let actual = URL(fileURLWithPath: arguments[comparisonIndex + 1])
        let baseline = URL(fileURLWithPath: arguments[comparisonIndex + 2])
        let report = try GoldenImageComparator.compare(actualURL: actual, baselineURL: baseline)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(report)
        if let outputIndex = arguments.firstIndex(of: "--output"), arguments.indices.contains(outputIndex + 1) {
            try data.write(to: URL(fileURLWithPath: arguments[outputIndex + 1]), options: .atomic)
        }
    } else if let benchmarkIndex = arguments.firstIndex(of: "--benchmark-image"), arguments.indices.contains(benchmarkIndex + 1) {
        let file = URL(fileURLWithPath: arguments[benchmarkIndex + 1])
        let report = try ImagePerformanceBenchmark.run(file: file)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(report)
        if let outputIndex = arguments.firstIndex(of: "--output"), arguments.indices.contains(outputIndex + 1) {
            try data.write(to: URL(fileURLWithPath: arguments[outputIndex + 1]), options: .atomic)
        }
    } else if let auditIndex = arguments.firstIndex(of: "--audit-folder"), arguments.indices.contains(auditIndex + 1) {
        let directory = URL(fileURLWithPath: arguments[auditIndex + 1], isDirectory: true)
        let report = ImageFolderAuditor.audit(directory: directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(report)
        if let outputIndex = arguments.firstIndex(of: "--output"), arguments.indices.contains(outputIndex + 1) {
            try data.write(to: URL(fileURLWithPath: arguments[outputIndex + 1]), options: .atomic)
        }
    } else {
        data = try ImageCapabilityProbe.jsonData()
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("imagepro-probe failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
