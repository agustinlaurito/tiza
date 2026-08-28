import XCTest
@testable import TeachBoard

final class StrokeSmoothingTests: XCTestCase {
    func testTooFewPointsReturnsInput() {
        let one = [CGPoint(x: 5, y: 5)]
        XCTAssertEqual(StrokeSmoothing.smooth(one), one)

        let two = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]
        XCTAssertEqual(StrokeSmoothing.smooth(two), two)
    }

    func testEmptyReturnsEmpty() {
        XCTAssertTrue(StrokeSmoothing.smooth([]).isEmpty)
    }

    func testSmoothProducesMorePoints() {
        let triangle = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 100, y: 0)
        ]
        let smoothed = StrokeSmoothing.smooth(triangle)
        XCTAssertGreaterThan(smoothed.count, triangle.count)
    }

    func testSmoothPreservesEndpoints() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 100, y: 50),
            CGPoint(x: 150, y: 0)
        ]
        let smoothed = StrokeSmoothing.smooth(points)

        XCTAssertEqual(smoothed.first!.x, points.first!.x, accuracy: 0.001)
        XCTAssertEqual(smoothed.first!.y, points.first!.y, accuracy: 0.001)
        XCTAssertEqual(smoothed.last!.x, points.last!.x, accuracy: 0.001)
        XCTAssertEqual(smoothed.last!.y, points.last!.y, accuracy: 0.001)
    }

    func testCollinearPointsSimplify() {
        let collinear = (0...20).map { CGPoint(x: Double($0) * 5, y: 0) }
        let smoothed = StrokeSmoothing.smooth(collinear)
        XCTAssertLessThanOrEqual(smoothed.count, collinear.count)
    }

    func testSmoothDoesNotProduceNaN() {
        let zigzag = (0..<10).map {
            CGPoint(x: Double($0) * 10, y: $0 % 2 == 0 ? 0 : 20)
        }
        let smoothed = StrokeSmoothing.smooth(zigzag)
        for p in smoothed {
            XCTAssertFalse(p.x.isNaN)
            XCTAssertFalse(p.y.isNaN)
        }
    }
}
