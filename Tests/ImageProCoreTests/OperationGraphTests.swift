import XCTest
@testable import ImageProCore

final class OperationGraphTests: XCTestCase {
    func testUndoThenAppendDiscardsRedoBranch() {
        var graph = OperationGraph()
        graph.append(.resize(ResizeParameters(size: PixelSize(width: 100, height: 100))))
        graph.append(.rotate(RotationParameters(degrees: 90)))
        XCTAssertNotNil(graph.undo())

        graph.append(.rotate(RotationParameters(degrees: 180)))

        XCTAssertEqual(graph.operations.count, 2)
        XCTAssertFalse(graph.canRedo)
        XCTAssertEqual(graph.cursor, 2)
    }

    func testCodableRoundTrip() throws {
        var graph = OperationGraph()
        graph.append(.crop(CropParameters(normalizedX: 0.1, normalizedY: 0.2, normalizedWidth: 0.5, normalizedHeight: 0.6)))
        let data = try JSONEncoder().encode(graph)
        XCTAssertEqual(try JSONDecoder().decode(OperationGraph.self, from: data), graph)
    }

    func testFiftyOperationsRoundTripWithUndoCursor() throws {
        var graph = OperationGraph()
        for index in 0..<50 {
            graph.append(.rotate(RotationParameters(degrees: index.isMultiple(of: 2) ? 90 : -90)))
        }
        for _ in 0..<7 { graph.undo() }

        let data = try JSONEncoder().encode(graph)
        let restored = try JSONDecoder().decode(OperationGraph.self, from: data)

        XCTAssertEqual(restored.operations.count, 50)
        XCTAssertEqual(restored.cursor, 43)
        XCTAssertTrue(restored.canUndo)
        XCTAssertTrue(restored.canRedo)
        XCTAssertEqual(restored, graph)
    }
}
