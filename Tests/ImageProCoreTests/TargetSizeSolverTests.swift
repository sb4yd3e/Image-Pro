import Foundation
import XCTest
@testable import ImageProCore

final class TargetSizeSolverTests: XCTestCase {
    func testFindsHighestQualityUnderTarget() throws {
        let result = try TargetSizeSolver.solve(targetBytes: 800, iterations: 12) { quality in
            Data(count: Int(quality * 1_000))
        }
        XCTAssertTrue(result.meetsTarget)
        XCTAssertLessThanOrEqual(result.data.count, 800)
        XCTAssertGreaterThan(result.quality, 0.79)
        XCTAssertLessThanOrEqual(result.quality, 0.801)
    }

    func testReturnsSmallestWhenTargetCannotBeReached() throws {
        let result = try TargetSizeSolver.solve(targetBytes: 10) { quality in
            Data(count: 100 + Int(quality * 10))
        }
        XCTAssertFalse(result.meetsTarget)
        XCTAssertEqual(result.quality, 0.35, accuracy: 0.0001)
    }
}
