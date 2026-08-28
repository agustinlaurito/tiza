import XCTest
@testable import Tiza

final class HitTestingTests: XCTestCase {
    func testStrokeHitOnLine() {
        let stroke = StrokeData(
            points: [[0, 0], [100, 0]],
            color: .black, thickness: 4, style: .pen
        )
        let element = Element(type: .stroke(stroke), zIndex: 0)

        XCTAssertTrue(HitTesting.isHit(point: CGPoint(x: 50, y: 0), element: element, threshold: 6))
        XCTAssertTrue(HitTesting.isHit(point: CGPoint(x: 50, y: 5), element: element, threshold: 6))
        XCTAssertFalse(HitTesting.isHit(point: CGPoint(x: 50, y: 20), element: element, threshold: 6))
    }

    func testStrokeHitMissFarPoint() {
        let stroke = StrokeData(
            points: [[10, 10], [20, 10], [30, 10]],
            color: .black, thickness: 2, style: .pen
        )
        let element = Element(type: .stroke(stroke), zIndex: 0)

        XCTAssertFalse(HitTesting.isHit(point: CGPoint(x: 100, y: 100), element: element, threshold: 6))
    }

    func testRectangleHit() {
        let shape = ShapeData(
            shapeType: .rectangle,
            origin: [10, 10], size: [80, 60], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )
        let element = Element(type: .shape(shape), zIndex: 0)

        XCTAssertTrue(HitTesting.isHit(point: CGPoint(x: 50, y: 40), element: element, threshold: 6))
        XCTAssertFalse(HitTesting.isHit(point: CGPoint(x: 200, y: 200), element: element, threshold: 6))
    }

    func testImageHit() {
        let img = ImageData(assetId: "test", origin: [100, 100], size: [200, 150], rotation: 0)
        let element = Element(type: .image(img), zIndex: 0)

        XCTAssertTrue(HitTesting.isHit(point: CGPoint(x: 200, y: 175), element: element, threshold: 6))
        XCTAssertFalse(HitTesting.isHit(point: CGPoint(x: 50, y: 50), element: element, threshold: 6))
    }

    func testTextHit() {
        let text = TextData(position: [50, 50], content: "Hello", fontSize: 24, color: .black, bold: false, rotation: 0)
        let element = Element(type: .text(text), zIndex: 0)

        XCTAssertTrue(HitTesting.isHit(point: CGPoint(x: 60, y: 40), element: element, threshold: 6))
        XCTAssertFalse(HitTesting.isHit(point: CGPoint(x: 400, y: 400), element: element, threshold: 6))
    }

    func testHitTestReturnsTopElement() {
        let bottom = Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [0, 0], size: [100, 100], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0)

        let top = Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [50, 50], size: [100, 100], rotation: 0,
            strokeColor: .red, fillColor: nil, strokeWidth: 2
        )), zIndex: 1)

        let hit = HitTesting.hitTest(point: CGPoint(x: 75, y: 75), elements: [bottom, top])
        XCTAssertEqual(hit?.id, top.id)
    }

    func testElementsInRect() {
        let inside = Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [10, 10], size: [30, 30], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0)

        let outside = Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [200, 200], size: [30, 30], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 1)

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let found = HitTesting.elementsInRect(rect, elements: [inside, outside])

        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.id, inside.id)
    }

    func testDistanceToSegment() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 10, y: 0)

        XCTAssertEqual(HitTesting.distanceToSegment(point: CGPoint(x: 5, y: 0), a: a, b: b), 0, accuracy: 0.001)
        XCTAssertEqual(HitTesting.distanceToSegment(point: CGPoint(x: 5, y: 3), a: a, b: b), 3, accuracy: 0.001)
        XCTAssertEqual(HitTesting.distanceToSegment(point: CGPoint(x: -5, y: 0), a: a, b: b), 5, accuracy: 0.001)
    }

    func testElementBoundsStroke() {
        let stroke = StrokeData(
            points: [[0, 0], [100, 50]],
            color: .black, thickness: 4, style: .pen
        )
        let element = Element(type: .stroke(stroke), zIndex: 0)
        let bounds = HitTesting.elementBounds(element)

        XCTAssertEqual(bounds.minX, -2, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, -2, accuracy: 0.001)
        XCTAssertEqual(bounds.width, 104, accuracy: 0.001)
        XCTAssertEqual(bounds.height, 54, accuracy: 0.001)
    }
}
