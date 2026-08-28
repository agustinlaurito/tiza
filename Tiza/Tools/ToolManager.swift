import AppKit
import Combine
import QuartzCore

final class ToolManager: ObservableObject {
    @Published var activeToolType: ToolType = .pen
    @Published var currentColor: CodableColor = .black
    @Published var currentThickness: Double = 2.0
    @Published var selectedElementIds: Set<UUID> = []
    @Published var lastShapeTool: ToolType = .rectangle
    @Published var lastInsertTool: ToolType = .table

    // In-progress stroke state (high-frequency, not @Published)
    var inProgressPoints: [CGPoint] = []
    var inProgressColor: CodableColor = .black
    var inProgressThickness: Double = 2.0
    var inProgressStyle: StrokeStyle = .pen
    var inProgressPressures: [Double]?

    // In-progress shape state
    var inProgressShapeType: ShapeType?
    var inProgressShapeOrigin: CGPoint = .zero
    var inProgressShapeSize: CGSize = .zero
    var inProgressShapeColor: CodableColor = .black
    var inProgressShapeThickness: Double = 2.0

    // In-progress connector state
    var inProgressConnectorSource: CGPoint?
    var inProgressConnectorTarget: CGPoint?
    var inProgressConnectorColor: CodableColor = .black

    var lastEventPressure: Double = 1.0
    var currentBackground: BoardBackground = .white

    // Selection state
    var dragSelectionRect: WorldRect?
    var dragSelectionCrossing: Bool = false
    var moveDelta: CGPoint = .zero
    var isMoving: Bool = false
    var resizingBounds: WorldRect?

    // Text editing state
    var textEditingPosition: WorldPoint?
    var textPreset: TextPreset?

    // Equation editing state
    var equationEditingPosition: WorldPoint?

    let animator = CanvasAnimator()

    var onNeedsRedraw: (() -> Void)? {
        get { animator.onNeedsRedraw }
        set { animator.onNeedsRedraw = newValue }
    }

    var clipboard: [Element] = []

    // Smart guides
    struct SmartGuide {
        enum Orientation { case horizontal, vertical }
        let orientation: Orientation
        let position: CGFloat
    }
    var activeSmartGuides: [SmartGuide] = []

    private var activeTool: (any Tool)?
    private var previousToolType: ToolType?

    init() {
        activeTool = PenTool(manager: self)
    }

    func switchTool(_ type: ToolType) {
        if (type == .text || type == .equation || type == .table) && activeToolType != type {
            previousToolType = activeToolType
        }

        activeTool?.cancel()
        clearTransientState()

        activeToolType = type
        activeTool = createTool(type)

        if type.isShapeTool {
            lastShapeTool = type
        } else if type.isInsertTool {
            lastInsertTool = type
        }

        if type != .select {
            selectedElementIds = []
        }
    }

    func restorePreviousTool() {
        guard let prev = previousToolType else { return }
        previousToolType = nil
        switchTool(prev)
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
        animator.deleteElementsAnimated(ids: selectedElementIds,
                                        document: context.document,
                                        undoManager: context.undoManager)
        selectedElementIds.subtract(selectedElementIds)
    }

    func deleteElementsAnimated(ids: Set<UUID>, document: TizaDocument, undoManager: UndoManager?) {
        selectedElementIds.subtract(ids)
        animator.deleteElementsAnimated(ids: ids, document: document, undoManager: undoManager)
    }

    func alignElementsAnimated(ids: Set<UUID>, alignment: AlignmentMode,
                                document: TizaDocument, undoManager: UndoManager?) {
        animator.alignElementsAnimated(ids: ids, alignment: alignment,
                                       document: document, undoManager: undoManager)
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
        case .connector: ConnectorTool(manager: self)
        case .table: TableTool(manager: self)
        case .equation: EquationTool(manager: self)
        case .line, .arrow, .rectangle, .ellipse, .triangle, .diamond, .star:
            ShapeTool(type: type, manager: self)
        }
    }

    private func clearTransientState() {
        inProgressPoints = []
        inProgressPressures = nil
        inProgressShapeType = nil
        inProgressConnectorSource = nil
        inProgressConnectorTarget = nil
        dragSelectionRect = nil
        dragSelectionCrossing = false
        moveDelta = .zero
        isMoving = false
        resizingBounds = nil
        textEditingPosition = nil
        equationEditingPosition = nil
    }
}
