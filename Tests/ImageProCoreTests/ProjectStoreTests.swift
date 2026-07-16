import Foundation
import XCTest
@testable import ImageProCore

final class ProjectStoreTests: XCTestCase {
    func testProjectRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("imagepro")
        defer { try? FileManager.default.removeItem(at: root) }

        let project = ProjectDocument(sourceRelativePath: "assets/original.jpg", sourceSHA256: "abc")
        let store = ProjectStore()
        try await store.save(project, to: root)
        let loaded = try await store.load(from: root)

        XCTAssertEqual(loaded.id, project.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("assets/masks").path))
    }

    func testSnapshotRoundTripIncludesSourceBaseActiveGraphAndMask() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("imagepro")
        defer { try? FileManager.default.removeItem(at: root) }
        var graph = OperationGraph()
        graph.append(.rotate(RotationParameters(degrees: 90)))
        let mask = MaskDocument(strokes: [
            MaskStroke(points: [MaskPoint(x: 0.5, y: 0.5)], diameter: 0.1)
        ])
        let snapshot = ProjectSnapshot(
            document: ProjectDocument(
                sourceRelativePath: "ignored",
                sourceSHA256: ModelValidator.sha256(of: Data("source".utf8)),
                operationGraph: graph,
                maskDocument: mask
            ),
            sourceData: Data("source".utf8),
            editingBaseData: Data("base".utf8),
            activeData: Data("active".utf8),
            renderedUndoData: [Data("undo-1".utf8), Data("undo-2".utf8)],
            renderedRedoData: [Data("redo-1".utf8)]
        )
        let store = ProjectStore()
        try await store.saveSnapshot(snapshot, to: root)
        let loaded = try await store.loadSnapshot(from: root)

        XCTAssertEqual(loaded.sourceData, snapshot.sourceData)
        XCTAssertEqual(loaded.editingBaseData, snapshot.editingBaseData)
        XCTAssertEqual(loaded.activeData, snapshot.activeData)
        XCTAssertEqual(loaded.document.operationGraph, graph)
        XCTAssertEqual(loaded.document.maskDocument, mask)
        XCTAssertEqual(loaded.renderedUndoData, snapshot.renderedUndoData)
        XCTAssertEqual(loaded.renderedRedoData, snapshot.renderedRedoData)
    }
}
