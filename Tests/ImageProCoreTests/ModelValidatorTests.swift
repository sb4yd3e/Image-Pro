import Foundation
import XCTest
@testable import ImageProCore

final class ModelValidatorTests: XCTestCase {
    func testSHAAndValidation() throws {
        let data = Data("model".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)

        let hash = ModelValidator.sha256(of: data)
        let manifest = ModelManifest(id: "test", version: "1", sha256: hash, minimumOS: "14.0", expectedInputs: [])
        XCTAssertNoThrow(try ModelValidator.validate(fileAt: url, manifest: manifest))
    }
}
