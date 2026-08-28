import AppKit

enum ToolType: String, CaseIterable, Identifiable {
    case select, pen, highlighter, eraser, text, line, arrow, rectangle, ellipse

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
        }
    }

    static let drawingTools: [ToolType] = allCases
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
    let document: TeachBoardDocument
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

    func constrain(_ point: CGPoint) -> CGPoint {
        instrumentManager?.constrain(point) ?? point
    }
}
