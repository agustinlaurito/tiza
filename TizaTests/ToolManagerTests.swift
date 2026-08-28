import XCTest
@testable import Tiza

final class ToolManagerTests: XCTestCase {
    func testDefaultTool() {
        let tm = ToolManager()
        XCTAssertEqual(tm.activeToolType, .pen)
    }

    func testSwitchTool() {
        let tm = ToolManager()
        tm.switchTool(.eraser)
        XCTAssertEqual(tm.activeToolType, .eraser)
    }

    func testSwitchToolClearsSelection() {
        let tm = ToolManager()
        tm.selectedElementIds = [UUID(), UUID()]
        tm.switchTool(.pen)
        XCTAssertTrue(tm.selectedElementIds.isEmpty)
    }

    func testSwitchToSelectKeepsSelection() {
        let tm = ToolManager()
        let ids: Set<UUID> = [UUID()]
        tm.selectedElementIds = ids
        tm.switchTool(.select)
        XCTAssertEqual(tm.selectedElementIds, ids)
    }

    func testCancelClearsTransientState() {
        let tm = ToolManager()
        tm.inProgressPoints = [CGPoint(x: 0, y: 0)]
        tm.inProgressShapeType = .rectangle
        tm.dragSelectionRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        tm.isMoving = true
        tm.textEditingPosition = CGPoint(x: 50, y: 50)

        tm.cancel()

        XCTAssertTrue(tm.inProgressPoints.isEmpty)
        XCTAssertNil(tm.inProgressShapeType)
        XCTAssertNil(tm.dragSelectionRect)
        XCTAssertFalse(tm.isMoving)
        XCTAssertNil(tm.textEditingPosition)
    }

    func testDefaultColorAndThickness() {
        let tm = ToolManager()
        XCTAssertEqual(tm.currentColor, .black)
        XCTAssertEqual(tm.currentThickness, 2.0)
    }

    func testSelectionBoundsEmpty() {
        let tm = ToolManager()
        let board = BoardData()
        XCTAssertNil(tm.selectionBounds(in: board))
    }

    func testSelectionBoundsWithSelected() {
        let tm = ToolManager()
        let element = Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [10, 20], size: [100, 50], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0)
        var board = BoardData()
        board.elements.append(element)
        tm.selectedElementIds = [element.id]

        let bounds = tm.selectionBounds(in: board)
        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds!.origin.x, 10, accuracy: 0.001)
        XCTAssertEqual(bounds!.origin.y, 20, accuracy: 0.001)
    }
}
