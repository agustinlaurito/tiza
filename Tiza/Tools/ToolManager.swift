import AppKit
import Combine
import QuartzCore

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
    var dragSelectionCrossing: Bool = false
    var moveDelta: CGPoint = .zero
    var isMoving: Bool = false
    var resizingBounds: WorldRect?

    // Text editing state
    var textEditingPosition: WorldPoint?
    var textPreset: TextPreset?

    // Delete animation state
    struct DeletingElement {
        let element: Element
        let center: CGPoint
        let startTime: CFTimeInterval
        var progress: CGFloat
    }
    var deletingElements: [DeletingElement] = []
    private var deleteAnimationTimer: Timer?

    // Alignment animation state
    var animatingOffsets: [UUID: CGPoint] = [:]
    private var alignAnimationTimer: Timer?
    private var alignInitialDeltas: [UUID: CGPoint] = [:]

    var onNeedsRedraw: (() -> Void)?

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
        if type == .text && activeToolType != .text {
            previousToolType = activeToolType
        }

        activeTool?.cancel()
        clearTransientState()

        activeToolType = type
        activeTool = createTool(type)

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
        deleteElementsAnimated(ids: selectedElementIds,
                               document: context.document,
                               undoManager: context.undoManager)
    }

    func deleteElementsAnimated(ids: Set<UUID>, document: TizaDocument, undoManager: UndoManager?) {
        guard let board = document.activeBoardData else { return }
        let selected = board.elements.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return }

        let now = CACurrentMediaTime()
        deletingElements.append(contentsOf: selected.map { element in
            let bounds = HitTesting.elementBounds(element)
            return DeletingElement(element: element,
                                   center: CGPoint(x: bounds.midX, y: bounds.midY),
                                   startTime: now, progress: 0)
        })

        selectedElementIds.subtract(ids)

        undoManager?.beginUndoGrouping()
        for id in ids {
            document.removeElement(id: id, undoManager: undoManager)
        }
        undoManager?.endUndoGrouping()

        startDeleteAnimation()
    }

    private func startDeleteAnimation() {
        guard deleteAnimationTimer == nil else { return }
        let duration: CFTimeInterval = 0.2

        deleteAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let now = CACurrentMediaTime()

            for i in self.deletingElements.indices {
                let elapsed = now - self.deletingElements[i].startTime
                self.deletingElements[i].progress = min(CGFloat(elapsed / duration), 1.0)
            }

            self.deletingElements.removeAll { $0.progress >= 1.0 }
            self.onNeedsRedraw?()

            if self.deletingElements.isEmpty {
                timer.invalidate()
                self.deleteAnimationTimer = nil
            }
        }
    }

    func alignElementsAnimated(ids: Set<UUID>, alignment: AlignmentMode,
                                document: TizaDocument, undoManager: UndoManager?) {
        guard let board = document.activeBoardData else { return }

        var oldCenters: [UUID: CGPoint] = [:]
        for element in board.elements where ids.contains(element.id) {
            let bounds = HitTesting.elementBounds(element)
            oldCenters[element.id] = CGPoint(x: bounds.midX, y: bounds.midY)
        }

        document.alignElements(ids: ids, alignment: alignment, undoManager: undoManager)

        guard let newBoard = document.activeBoardData else { return }
        var deltas: [UUID: CGPoint] = [:]
        for element in newBoard.elements where ids.contains(element.id) {
            let newBounds = HitTesting.elementBounds(element)
            let newCenter = CGPoint(x: newBounds.midX, y: newBounds.midY)
            if let oldCenter = oldCenters[element.id] {
                let dx = oldCenter.x - newCenter.x
                let dy = oldCenter.y - newCenter.y
                if abs(dx) > 0.5 || abs(dy) > 0.5 {
                    deltas[element.id] = CGPoint(x: dx, y: dy)
                }
            }
        }

        guard !deltas.isEmpty else { return }

        alignAnimationTimer?.invalidate()
        alignInitialDeltas = deltas
        animatingOffsets = deltas

        let startTime = CACurrentMediaTime()
        let duration: CFTimeInterval = 0.3

        alignAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(CGFloat(elapsed / duration), 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3)

            var newOffsets: [UUID: CGPoint] = [:]
            for (id, delta) in self.alignInitialDeltas {
                newOffsets[id] = CGPoint(x: delta.x * (1.0 - eased),
                                        y: delta.y * (1.0 - eased))
            }
            self.animatingOffsets = newOffsets
            self.onNeedsRedraw?()

            if progress >= 1.0 {
                timer.invalidate()
                self.alignAnimationTimer = nil
                self.animatingOffsets = [:]
                self.alignInitialDeltas = [:]
                self.onNeedsRedraw?()
            }
        }
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
        case .line, .arrow, .rectangle, .ellipse, .triangle, .diamond, .star:
            ShapeTool(type: type, manager: self)
        }
    }

    private func clearTransientState() {
        inProgressPoints = []
        inProgressShapeType = nil
        dragSelectionRect = nil
        dragSelectionCrossing = false
        moveDelta = .zero
        isMoving = false
        resizingBounds = nil
        textEditingPosition = nil
    }
}
