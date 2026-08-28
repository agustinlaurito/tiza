import XCTest
@testable import Tiza

final class BoardDataTests: XCTestCase {
    func testNextZIndexEmpty() {
        let board = BoardData()
        XCTAssertEqual(board.nextZIndex, 0)
    }

    func testNextZIndexIncrementing() {
        var board = BoardData()
        board.elements.append(Element(type: .stroke(StrokeData(
            points: [[0, 0]], color: .black, thickness: 2, style: .pen
        )), zIndex: 0))
        XCTAssertEqual(board.nextZIndex, 1)

        board.elements.append(Element(type: .stroke(StrokeData(
            points: [[10, 10]], color: .black, thickness: 2, style: .pen
        )), zIndex: 5))
        XCTAssertEqual(board.nextZIndex, 6)
    }

    func testBoundingBoxEmpty() {
        let board = BoardData()
        XCTAssertNil(board.boundingBox)
    }

    func testBoundingBoxSingleElement() {
        var board = BoardData()
        board.elements.append(Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [10, 20], size: [100, 50], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0))

        let bounds = board.boundingBox
        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds!.origin.x, 10, accuracy: 0.001)
        XCTAssertEqual(bounds!.origin.y, 20, accuracy: 0.001)
        XCTAssertEqual(bounds!.width, 100, accuracy: 0.001)
        XCTAssertEqual(bounds!.height, 50, accuracy: 0.001)
    }

    func testBoundingBoxMultipleElements() {
        var board = BoardData()
        board.elements.append(Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [0, 0], size: [50, 50], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0))
        board.elements.append(Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [100, 100], size: [50, 50], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 1))

        let bounds = board.boundingBox!
        XCTAssertEqual(bounds.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(bounds.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(bounds.maxX, 150, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 150, accuracy: 0.001)
    }

    func testBoardCodableRoundTrip() throws {
        var board = BoardData()
        board.elements.append(Element(type: .stroke(StrokeData(
            points: [[1, 2], [3, 4]], color: .red, thickness: 3, style: .pen
        )), zIndex: 0))
        board.elements.append(Element(type: .text(TextData(
            position: [50, 50], content: "Test", fontSize: 18, color: .blue, bold: true, rotation: 0
        )), zIndex: 1))

        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(BoardData.self, from: data)

        XCTAssertEqual(decoded.id, board.id)
        XCTAssertEqual(decoded.elements.count, 2)
        XCTAssertEqual(decoded.elements[0].type, board.elements[0].type)
        XCTAssertEqual(decoded.elements[1].type, board.elements[1].type)
    }
}
