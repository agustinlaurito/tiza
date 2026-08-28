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
                let el = board.elements.first { $0.id == selectedId }
                if el?.locked != true {
                    dragMode = .resizing(handle: handle, originalBounds: bounds,
                                         elementId: selectedId, start: point)
                    return
                }
            }
        }

        if let hitElement = HitTesting.hitTest(point: point, elements: board.elements,
                                                threshold: threshold) {
            let groupExpanded = context.document.idsInSameGroup(as: [hitElement.id])
            if shift {
                if manager.selectedElementIds.contains(hitElement.id) {
                    manager.selectedElementIds.subtract(groupExpanded)
                    dragMode = .none
                } else {
                    manager.selectedElementIds.formUnion(groupExpanded)
                    let anyLocked = board.elements.filter { manager.selectedElementIds.contains($0.id) }.contains { $0.locked }
                    if !anyLocked {
                        dragMode = .moving(start: point)
                        manager.isMoving = true
                        manager.moveDelta = .zero
                    }
                }
            } else if manager.selectedElementIds.contains(hitElement.id) {
                let anyLocked = board.elements.filter { manager.selectedElementIds.contains($0.id) }.contains { $0.locked }
                if !anyLocked {
                    dragMode = .moving(start: point)
                    manager.isMoving = true
                    manager.moveDelta = .zero
                }
            } else {
                manager.selectedElementIds = groupExpanded
                let anyLocked = board.elements.filter { groupExpanded.contains($0.id) }.contains { $0.locked }
                if !anyLocked {
                    dragMode = .moving(start: point)
                    manager.isMoving = true
                    manager.moveDelta = .zero
                }
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
            var delta = point - start
            if let board = context.boardData {
                delta = snapWithSmartGuides(delta: delta, board: board)
            }
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
            let delta = manager.moveDelta
            if abs(delta.x) > 0.5 || abs(delta.y) > 0.5 {
                context.moveElements(ids: manager.selectedElementIds, delta: delta)
            }
            manager.moveDelta = .zero
            manager.isMoving = false
            manager.activeSmartGuides = []

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
        manager.activeSmartGuides = []
        dragMode = .none
    }

    var cursor: NSCursor { .arrow }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func snapWithSmartGuides(delta: CGPoint, board: BoardData) -> CGPoint {
        let selectedIds = manager.selectedElementIds
        let selected = board.elements.filter { selectedIds.contains($0.id) }
        let others = board.elements.filter { !selectedIds.contains($0.id) && !$0.locked }

        var combinedBounds = HitTesting.elementBounds(selected[0])
        for el in selected.dropFirst() {
            combinedBounds = combinedBounds.union(HitTesting.elementBounds(el))
        }
        let movedBounds = combinedBounds.offsetBy(dx: delta.x, dy: delta.y)

        let bg = manager.currentBackground
        if (bg == .grid || bg == .dottedGrid), others.isEmpty {
            return snapToGrid(delta: delta, movedBounds: movedBounds, spacing: 20)
        }

        guard !selected.isEmpty, !others.isEmpty else {
            if bg == .grid || bg == .dottedGrid {
                return snapToGrid(delta: delta, movedBounds: movedBounds, spacing: 20)
            }
            manager.activeSmartGuides = []
            return delta
        }

        let snapThreshold: CGFloat = 5

        var snapX: CGFloat? = nil
        var snapY: CGFloat? = nil
        var guides: [ToolManager.SmartGuide] = []

        let movingEdgesX = [movedBounds.minX, movedBounds.midX, movedBounds.maxX]
        let movingEdgesY = [movedBounds.minY, movedBounds.midY, movedBounds.maxY]

        for other in others {
            let ob = HitTesting.elementBounds(other)
            let targetEdgesX = [ob.minX, ob.midX, ob.maxX]
            let targetEdgesY = [ob.minY, ob.midY, ob.maxY]

            for mx in movingEdgesX {
                for tx in targetEdgesX {
                    let dist = abs(mx - tx)
                    if dist < snapThreshold {
                        if snapX == nil || dist < abs(movingEdgesX[0] + (snapX! - delta.x) - tx) {
                            snapX = delta.x + (tx - mx)
                            guides.removeAll { $0.orientation == .vertical }
                            guides.append(.init(orientation: .vertical, position: tx))
                        }
                    }
                }
            }

            for my in movingEdgesY {
                for ty in targetEdgesY {
                    let dist = abs(my - ty)
                    if dist < snapThreshold {
                        if snapY == nil || dist < abs(movingEdgesY[0] + (snapY! - delta.y) - ty) {
                            snapY = delta.y + (ty - my)
                            guides.removeAll { $0.orientation == .horizontal }
                            guides.append(.init(orientation: .horizontal, position: ty))
                        }
                    }
                }
            }
        }

        manager.activeSmartGuides = guides
        var result = CGPoint(x: snapX ?? delta.x, y: snapY ?? delta.y)

        if bg == .grid || bg == .dottedGrid {
            let gridSnapped = snapToGrid(delta: result, movedBounds: combinedBounds.offsetBy(dx: result.x, dy: result.y), spacing: 20)
            if snapX == nil { result.x = gridSnapped.x }
            if snapY == nil { result.y = gridSnapped.y }
        }

        return result
    }

    private func snapToGrid(delta: CGPoint, movedBounds: CGRect, spacing: CGFloat) -> CGPoint {
        let snapThreshold: CGFloat = spacing / 3
        var dx = delta.x, dy = delta.y

        let nearestX = round(movedBounds.minX / spacing) * spacing
        if abs(movedBounds.minX - nearestX) < snapThreshold {
            dx += nearestX - movedBounds.minX
        }
        let nearestY = round(movedBounds.minY / spacing) * spacing
        if abs(movedBounds.minY - nearestY) < snapThreshold {
            dy += nearestY - movedBounds.minY
        }
        return CGPoint(x: dx, y: dy)
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
