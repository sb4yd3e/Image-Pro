import XCTest
@testable import ImageProCore

final class PixelSizeTests: XCTestCase {
    func testFitPreservesAspectRatio() {
        let source = PixelSize(width: 4_000, height: 3_000)
        XCTAssertEqual(source.fitting(within: PixelSize(width: 1_000, height: 1_000)), PixelSize(width: 1_000, height: 750))
    }

    func testFitDoesNotUpscaleByDefault() {
        let source = PixelSize(width: 640, height: 480)
        XCTAssertEqual(source.fitting(within: PixelSize(width: 2_000, height: 2_000)), source)
    }

    func testLongEdgeConstraint() {
        XCTAssertEqual(
            PixelSize(width: 4_032, height: 3_024).constrainedTo(longEdge: 2_016),
            PixelSize(width: 2_016, height: 1_512)
        )
    }
}
