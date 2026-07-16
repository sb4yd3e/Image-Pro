import Foundation
import XCTest
@testable import ImageProCore

final class ModelStoreTests: XCTestCase {
    func testInstallsZipModelPack() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let package = temporary.appendingPathComponent("zip-test.imagepromodel", isDirectory: true)
        let payload = package.appendingPathComponent("payload/model", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let manifest = ModelPackageManifest(
            id: "zip-test",
            displayName: "ZIP Test",
            version: "1",
            capabilities: [.erase],
            engine: .coreML,
            minimumOS: "14.0",
            minimumMemoryGB: 1,
            license: "MIT",
            entrypoint: "payload/model",
            installedBytes: 0
        )
        try JSONEncoder().encode(manifest).write(
            to: package.appendingPathComponent(ModelStore.manifestFilename)
        )
        let archive = temporary.appendingPathComponent("zip-test.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", package.path, archive.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let store = ModelStore(rootURL: temporary.appendingPathComponent("store", isDirectory: true))
        let installed = try store.installPackage(at: archive)
        XCTAssertEqual(installed.manifest.id, "zip-test")
        XCTAssertNotNil(try store.resolveActiveModel(for: .erase))
        try? FileManager.default.removeItem(at: temporary)
    }

    func testInstallActivateResolveAndRemoveExternalModel() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let package = temporary.appendingPathComponent("test.imagepromodel", isDirectory: true)
        let payload = package.appendingPathComponent("payload/Test.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: payload.appendingPathComponent("weights.bin"))

        let manifest = ModelPackageManifest(
            id: "test-model",
            displayName: "Test Model",
            version: "1.0.0",
            capabilities: [.erase, .upscale],
            engine: .coreML,
            minimumOS: "14.0",
            minimumMemoryGB: 8,
            license: "MIT",
            entrypoint: "payload/Test.mlmodelc",
            installedBytes: 5
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: package.appendingPathComponent(ModelStore.manifestFilename)
        )

        let store = ModelStore(rootURL: temporary.appendingPathComponent("store", isDirectory: true))
        let installed = try store.installPackage(at: package)
        XCTAssertEqual(installed.manifest.id, "test-model")
        XCTAssertNotNil(try store.resolveActiveModel(for: .erase))
        XCTAssertNotNil(try store.resolveActiveModel(for: .upscale))

        try store.activate(modelID: "test-model", version: "1.0.0", for: .erase)
        let resolved = try XCTUnwrap(store.resolveActiveModel(for: .erase))
        XCTAssertEqual(resolved.lastPathComponent, "Test.mlmodelc")

        try store.remove(modelID: "test-model", version: "1.0.0")
        XCTAssertNil(try store.resolveActiveModel(for: .erase))
        XCTAssertTrue(try store.installedModels().isEmpty)
        try? FileManager.default.removeItem(at: temporary)
    }

    func testInstallingNewVersionReplacesStaleActiveSelection() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let storeRoot = temporary.appendingPathComponent("store", isDirectory: true)
        let store = ModelStore(rootURL: storeRoot)

        let first = try makePackage(id: "upgrade-test", version: "1", inside: temporary)
        _ = try store.installPackage(at: first)
        try FileManager.default.removeItem(
            at: storeRoot.appendingPathComponent("Packages/upgrade-test/1", isDirectory: true)
        )
        XCTAssertNil(try store.resolveActiveModel(for: .upscale))

        let second = try makePackage(id: "upgrade-test", version: "2", inside: temporary)
        _ = try store.installPackage(at: second)
        let active = try XCTUnwrap(store.activeModel(for: .upscale))
        XCTAssertEqual(active.manifest.version, "2")
        XCTAssertEqual(try store.resolveActiveModel(for: .upscale)?.lastPathComponent, "Model.mlmodelc")
    }

    func testRejectsEntrypointOutsidePackage() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let package = temporary.appendingPathComponent("unsafe.imagepromodel", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let manifest = ModelPackageManifest(
            id: "unsafe",
            displayName: "Unsafe",
            version: "1",
            capabilities: [.erase],
            engine: .coreML,
            minimumOS: "14.0",
            minimumMemoryGB: 8,
            license: "MIT",
            entrypoint: "../outside",
            installedBytes: 0
        )
        try JSONEncoder().encode(manifest).write(
            to: package.appendingPathComponent(ModelStore.manifestFilename)
        )
        let store = ModelStore(rootURL: temporary.appendingPathComponent("store", isDirectory: true))
        XCTAssertThrowsError(try store.installPackage(at: package)) { error in
            guard case ModelPackageError.unsafePath = error else {
                return XCTFail("Expected unsafePath, got \(error)")
            }
        }
        try? FileManager.default.removeItem(at: temporary)
    }

    func testStreamingFileHashMatchesDataHash() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let data = Data(repeating: 0xA5, count: 9 * 1_024 * 1_024)
        try data.write(to: url)
        XCTAssertEqual(
            try ModelValidator.sha256(fileAt: url),
            ModelValidator.sha256(of: data)
        )
        try? FileManager.default.removeItem(at: url)
    }

    private func makePackage(id: String, version: String, inside root: URL) throws -> URL {
        let package = root.appendingPathComponent("\(id)-\(version).imagepromodel", isDirectory: true)
        let payload = package.appendingPathComponent("payload/Model.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try Data("model-\(version)".utf8).write(to: payload.appendingPathComponent("weights.bin"))
        let manifest = ModelPackageManifest(
            id: id,
            displayName: "Upgrade Test",
            version: version,
            capabilities: [.upscale],
            engine: .coreML,
            minimumOS: "14.0",
            minimumMemoryGB: 1,
            license: "MIT",
            entrypoint: "payload/Model.mlmodelc",
            installedBytes: 0
        )
        try JSONEncoder().encode(manifest).write(
            to: package.appendingPathComponent(ModelStore.manifestFilename)
        )
        return package
    }
}
