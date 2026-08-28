import AppKit
import Combine

final class ToolManager: ObservableObject {
    @Published var activeToolType: ToolType = .pen
    @Published var currentColor: CodableColor = .black
    @Published var currentThickness: Double = 2.0
    @Published var selectedElementIds: Set<UUID> = []

    // In-progress stroke state (high-frequency, not @Published)
    var inProgressPoints: [CGPoint] = []
    var inProgressColor: CodableColor = .black
    var inProgressThickness: Double = 2.0
    var inProgressStyle: StrokeStyle = .pen

    // In-progress shape state
    var inProgressShapeType: ShapeType?
    var inProgressShapeOrigin: CGPoint = .zero
    var inProgressShapeSize: CGSize = .zero
    var inProgressShapeColor: CodableColor = .black
    var inProgressShapeThickness: Double = 2.0

    // Selection state
    var dragSelectionRect: WorldRect?
    var moveDelta: CGPoint = .zero
    var isMoving: Bool = false

    // Text editing state
    var textEditingPosition: WorldPoint?

    private var activeTool: (any Tool)?

    init() {
        activeTool = PenTool(manager: self)
    }

    func switchTool(_ type: ToolType) {
        activeTool?.cancel()
        clearTransientState()

        activeToolType = type
        activeTool = createTool(type)

        if type != .select {
            selectedElementIds = []
        }
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        activeTool?.pointerDown(at: point, context: context)
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        activeTool?.pointerDragged(to: point, context: context)
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        activeTool?.pointerUp(at: point, context: context)
    }

    func cancel() {
        activeTool?.cancel()
        clearTransientState()
    }

    var cursor: NSCursor {
        activeTool?.cursor ?? .arrow
    }

    func deleteSelection(context: ToolContext) {
        guard !selectedElementIds.isEmpty else { return }
        let ids = selectedElementIds

        context.undoManager?.beginUndoGrouping()
        for id in ids {
            context.removeElement(id: id)
        }
        context.undoManager?.endUndoGrouping()

        selectedElementIds = []
    }

    func selectionBounds(in board: BoardData) -> WorldRect? {
        let selected = board.elements.filter { selectedElementIds.contains($0.id) }
        guard !selected.isEmpty else { return nil }

        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        for element in selected {
            let bounds = HitTesting.elementBounds(element)
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func createTool(_ type: ToolType) -> any Tool {
        switch type {
        case .select: SelectionTool(manager: self)
        case .pen: PenTool(manager: self)
        case .highlighter: HighlighterTool(manager: self)
        case .eraser: EraserTool(manager: self)
        case .text: TextTool(manager: self)
        case .line, .arrow, .rectangle, .ellipse: ShapeTool(type: type, manager: self)
        }
    }

    private func clearTransientState() {
        inProgressPoints = []
        inProgressShapeType = nil
        dragSelectionRect = nil
        moveDelta = .zero
        isMoving = false
        textEditingPosition = nil
    }
}
