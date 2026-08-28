import AppKit

enum ToolType: String, CaseIterable, Identifiable {
    case select, pen, highlighter, eraser, text, line, arrow, rectangle, ellipse, triangle, diamond, star
    case connector, table, equation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select: "Select"
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .text: "Text"
        case .line: "Line"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .triangle: "Triangle"
        case .diamond: "Diamond"
        case .star: "Star"
        case .connector: "Connector"
        case .table: "Table"
        case .equation: "Equation"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .text: "textformat"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .triangle: "triangle"
        case .diamond: "diamond"
        case .star: "star"
        case .connector: "arrow.triangle.branch"
        case .table: "tablecells"
        case .equation: "function"
        }
    }

    var shortcutKey: Character {
        switch self {
        case .select: "v"
        case .pen: "p"
        case .highlighter: "m"
        case .eraser: "e"
        case .text: "t"
        case .line: "l"
        case .arrow: "a"
        case .rectangle: "r"
        case .ellipse: "o"
        case .triangle: "g"
        case .diamond: "d"
        case .star: "s"
        case .connector: "c"
        case .table: "b"
        case .equation: "q"
        }
    }

    static let drawingTools: [ToolType] = allCases

    static let primaryTools: [ToolType] = [.select, .pen, .highlighter, .eraser, .text]
    static let shapeTools: [ToolType] = [.line, .arrow, .rectangle, .ellipse, .triangle, .diamond, .star]
    static let insertTools: [ToolType] = [.connector, .table, .equation]

    var isShapeTool: Bool { Self.shapeTools.contains(self) }
    var isInsertTool: Bool { Self.insertTools.contains(self) }
}

protocol Tool: AnyObject {
    var toolType: ToolType { get }
    func pointerDown(at point: WorldPoint, context: ToolContext)
    func pointerDragged(to point: WorldPoint, context: ToolContext)
    func pointerUp(at point: WorldPoint, context: ToolContext)
    func cancel()
    var cursor: NSCursor { get }
}

struct ToolContext {
    let document: TizaDocument
    let undoManager: UndoManager?
    let toolManager: ToolManager
    var instrumentManager: InstrumentManager?

    var activeBoardId: UUID? { document.activeBoardReference?.id }
    var boardData: BoardData? { document.activeBoardData }
    var color: CodableColor { toolManager.currentColor }
    var thickness: Double { toolManager.currentThickness }

    func addElement(_ element: Element) {
        document.addElement(element, undoManager: undoManager)
    }

    func removeElement(id: UUID) {
        document.removeElement(id: id, undoManager: undoManager)
    }

    func moveElements(ids: Set<UUID>, delta: CGPoint) {
        document.moveElements(ids: ids, delta: delta, undoManager: undoManager)
    }

    func resizeElement(id: UUID, newBounds: CGRect) {
        document.resizeElement(id: id, newBounds: newBounds, undoManager: undoManager)
    }

    func moveEndpoint(id: UUID, handle: HitTesting.HandlePosition, to point: CGPoint) {
        document.moveEndpoint(id: id, handle: handle, to: point, undoManager: undoManager)
    }

    func constrain(_ point: CGPoint) -> CGPoint {
        instrumentManager?.constrain(point) ?? point
    }
}
