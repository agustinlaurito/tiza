import AppKit

final class SelectionTool: Tool {
    var toolType: ToolType { .select }
    unowned let manager: ToolManager

    private enum DragMode {
        case none
        case marquee(start: WorldPoint)
        case moving(start: WorldPoint)
    }

    private var dragMode: DragMode = .none

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        guard let board = context.boardData else { return }

        let threshold = HitTesting.defaultThreshold

        if let hitElement = HitTesting.hitTest(point: point, elements: board.elements,
                                                threshold: threshold) {
            if manager.selectedElementIds.contains(hitElement.id) {
                dragMode = .moving(start: point)
                manager.isMoving = true
                manager.moveDelta = .zero
            } else {
                manager.selectedElementIds = [hitElement.id]
                dragMode = .moving(start: point)
                manager.isMoving = true
                manager.moveDelta = .zero
            }
        } else {
            manager.selectedElementIds = []
            dragMode = .marquee(start: point)
            manager.dragSelectionRect = nil
        }
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        switch dragMode {
        case .none:
            break

        case .marquee(let start):
            let rect = rectFromPoints(start, point)
            manager.dragSelectionRect = rect

            if let board = context.boardData {
                let hits = HitTesting.elementsInRect(rect, elements: board.elements)
                manager.selectedElementIds = Set(hits.map(\.id))
            }

        case .moving(let start):
            let delta = point - start
            manager.moveDelta = delta
        }
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        switch dragMode {
        case .none:
            break

        case .marquee:
            manager.dragSelectionRect = nil

        case .moving(let start):
            let delta = point - start
            if abs(delta.x) > 0.5 || abs(delta.y) > 0.5 {
                context.moveElements(ids: manager.selectedElementIds, delta: delta)
            }
            manager.moveDelta = .zero
            manager.isMoving = false
        }

        dragMode = .none
    }

    func cancel() {
        manager.selectedElementIds = []
        manager.dragSelectionRect = nil
        manager.moveDelta = .zero
        manager.isMoving = false
        dragMode = .none
    }

    var cursor: NSCursor { .arrow }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
