import CryptoKit
import Foundation

public struct ModelManifest: Codable, Hashable, Sendable {
    public let id: String
    public let version: String
    public let sha256: String
    public let minimumOS: String
    public let expectedInputs: [String]

    public init(id: String, version: String, sha256: String, minimumOS: String, expectedInputs: [String]) {
        self.id = id
        self.version = version
        self.sha256 = sha256.lowercased()
        self.minimumOS = minimumOS
        self.expectedInputs = expectedInputs
    }
}

public enum ModelValidationError: Error, Equatable {
    case missingFile
    case checksumMismatch(expected: String, actual: String)
}

public enum ModelValidator {
    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(fileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 4 * 1_024 * 1_024)
            guard let data, !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func validate(fileAt url: URL, manifest: ModelManifest) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ModelValidationError.missingFile
        }
        let actual = try sha256(fileAt: url)
        guard actual == manifest.sha256 else {
            throw ModelValidationError.checksumMismatch(expected: manifest.sha256, actual: actual)
        }
    }
}
