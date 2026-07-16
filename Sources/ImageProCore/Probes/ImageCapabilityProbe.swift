import Foundation

public struct ImageCapabilityReport: Codable, Sendable {
    public let generatedAt: Date
    public let operatingSystem: String
    public let architecture: String
    public let readableTypeIdentifiers: [String]
    public let writableTypeIdentifiers: [String]
    public let applicationWritableFormats: [String]
    public let webPEncoderVersion: String

    public init(
        generatedAt: Date = Date(),
        operatingSystem: String = ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: String = {
            #if arch(arm64)
            "arm64"
            #elseif arch(x86_64)
            "x86_64"
            #else
            "unknown"
            #endif
        }(),
        readableTypeIdentifiers: [String] = ImageIOService.supportedSourceTypeIdentifiers.sorted(),
        writableTypeIdentifiers: [String] = ImageIOService.supportedDestinationTypeIdentifiers.sorted(),
        applicationWritableFormats: [String] = ImageFormat.allCases
            .filter { $0 != .automatic && ImageEncoderService.supports($0) }
            .map(\.displayName),
        webPEncoderVersion: String = WebPEncoder.version
    ) {
        self.generatedAt = generatedAt
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.readableTypeIdentifiers = readableTypeIdentifiers
        self.writableTypeIdentifiers = writableTypeIdentifiers
        self.applicationWritableFormats = applicationWritableFormats
        self.webPEncoderVersion = webPEncoderVersion
    }
}

public enum ImageCapabilityProbe {
    public static func report() -> ImageCapabilityReport {
        ImageCapabilityReport()
    }

    public static func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(report())
    }
}
