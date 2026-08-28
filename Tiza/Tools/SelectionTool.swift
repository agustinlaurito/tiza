import AppKit

final class SelectionTool: Tool {
    var toolType: ToolType { .select }
    unowned let manager: ToolManager

    private enum DragMode {
        case none
        case marquee(start: WorldPoint)
        case moving(start: WorldPoint)
        case resizing(handle: HitTesting.HandlePosition, originalBounds: WorldRect,
                      elementId: UUID, start: WorldPoint)
    }

    private var dragMode: DragMode = .none
    private var selectionBeforeMarquee: Set<UUID> = []

    init(manager: ToolManager) {
        self.manager = manager
    }

    private var isShiftHeld: Bool {
        NSEvent.modifierFlags.contains(.shift)
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        guard let board = context.boardData else { return }
        let shift = isShiftHeld

        let threshold = HitTesting.defaultThreshold

        if !shift, manager.selectedElementIds.count == 1,
           let selectedId = manager.selectedElementIds.first,
           let bounds = manager.selectionBounds(in: board) {
            let handleSize: CGFloat = 12
            if let handle = HitTesting.hitTestHandle(point: point, bounds: bounds,
                                                      handleSize: handleSize) {
                dragMode = .resizing(handle: handle, originalBounds: bounds,
                                     elementId: selectedId, start: point)
                return
            }
        }

        if let hitElement = HitTesting.hitTest(point: point, elements: board.elements,
                                                threshold: threshold) {
            if shift {
                if manager.selectedElementIds.contains(hitElement.id) {
                    manager.selectedElementIds.remove(hitElement.id)
                    dragMode = .none
                } else {
                    manager.selectedElementIds.insert(hitElement.id)
                    dragMode = .moving(start: point)
                    manager.isMoving = true
                    manager.moveDelta = .zero
                }
            } else if manager.selectedElementIds.contains(hitElement.id) {
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
            selectionBeforeMarquee = shift ? manager.selectedElementIds : []
            if !shift {
                manager.selectedElementIds = []
            }
            dragMode = .marquee(start: point)
            manager.dragSelectionRect = nil
            manager.dragSelectionCrossing = false
        }
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        switch dragMode {
        case .none:
            break

        case .marquee(let start):
            let crossing = point.x < start.x
            let rect = rectFromPoints(start, point)
            manager.dragSelectionRect = rect
            manager.dragSelectionCrossing = crossing

            if let board = context.boardData {
                let hits: [Element]
                if crossing {
                    hits = HitTesting.elementsInRect(rect, elements: board.elements)
                } else {
                    hits = HitTesting.elementsFullyInRect(rect, elements: board.elements)
                }
                manager.selectedElementIds = selectionBeforeMarquee.union(Set(hits.map(\.id)))
            }

        case .moving(let start):
            let delta = point - start
            manager.moveDelta = delta

        case .resizing(let handle, let originalBounds, _, let start):
            let dx = point.x - start.x
            let dy = point.y - start.y
            let newBounds = computeResizedBounds(original: originalBounds, handle: handle,
                                                  dx: dx, dy: dy)
            manager.resizingBounds = newBounds
        }
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        switch dragMode {
        case .none:
            break

        case .marquee:
            manager.dragSelectionRect = nil
            manager.dragSelectionCrossing = false

        case .moving(let start):
            let delta = point - start
            if abs(delta.x) > 0.5 || abs(delta.y) > 0.5 {
                context.moveElements(ids: manager.selectedElementIds, delta: delta)
            }
            manager.moveDelta = .zero
            manager.isMoving = false

        case .resizing(let handle, let originalBounds, let elementId, let start):
            let dx = point.x - start.x
            let dy = point.y - start.y
            let newBounds = computeResizedBounds(original: originalBounds, handle: handle,
                                                  dx: dx, dy: dy)
            if newBounds.width > 5 && newBounds.height > 5 {
                context.resizeElement(id: elementId, newBounds: newBounds)
            }
            manager.resizingBounds = nil
        }

        dragMode = .none
    }

    func cancel() {
        manager.selectedElementIds = []
        manager.dragSelectionRect = nil
        manager.dragSelectionCrossing = false
        manager.moveDelta = .zero
        manager.isMoving = false
        manager.resizingBounds = nil
        dragMode = .none
    }

    var cursor: NSCursor { .arrow }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func computeResizedBounds(original: WorldRect, handle: HitTesting.HandlePosition,
                                       dx: CGFloat, dy: CGFloat) -> WorldRect {
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY

        switch handle {
        case .topLeft:
            minX += dx; minY += dy
        case .topRight:
            maxX += dx; minY += dy
        case .bottomLeft:
            minX += dx; maxY += dy
        case .bottomRight:
            maxX += dx; maxY += dy
        }

        let minSize: CGFloat = 10
        if maxX - minX < minSize { maxX = minX + minSize }
        if maxY - minY < minSize { maxY = minY + minSize }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
