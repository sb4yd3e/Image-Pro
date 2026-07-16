import Foundation
import XCTest

final class OfflineArchitectureTests: XCTestCase {
    func testImageProcessingCoreContainsNoNetworkClientAPIs() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ImageProCore", isDirectory: true)
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        let forbidden = ["URLSession", "NWConnection", "CFNetwork", "http://", "https://"]
        var findings: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for token in forbidden where text.contains(token) {
                findings.append("\(url.lastPathComponent): \(token)")
            }
        }
        XCTAssertTrue(findings.isEmpty, "Core network references found: \(findings.joined(separator: ", "))")
    }
}
