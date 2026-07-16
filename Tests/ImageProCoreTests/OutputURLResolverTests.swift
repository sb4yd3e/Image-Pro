import Foundation
import XCTest
@testable import ImageProCore

final class OutputURLResolverTests: XCTestCase {
    func testCollisionPolicies() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let desired = directory.appendingPathComponent("photo.jpg")
        try Data("existing".utf8).write(to: desired)

        XCTAssertEqual(OutputURLResolver.resolve(desired, policy: .replace), desired)
        XCTAssertNil(OutputURLResolver.resolve(desired, policy: .skip))
        XCTAssertEqual(
            OutputURLResolver.resolve(desired, policy: .uniqueName)?.lastPathComponent,
            "photo-2.jpg"
        )

        try Data("second".utf8).write(to: directory.appendingPathComponent("photo-2.jpg"))
        XCTAssertEqual(
            OutputURLResolver.resolve(desired, policy: .uniqueName)?.lastPathComponent,
            "photo-3.jpg"
        )
    }
}
