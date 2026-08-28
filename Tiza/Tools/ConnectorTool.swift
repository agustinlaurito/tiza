import AppKit

final class ConnectorTool: Tool {
    var toolType: ToolType { .connector }
    unowned let manager: ToolManager
    private var startPoint: WorldPoint?
    private var sourceElementId: UUID?

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        startPoint = point
        sourceElementId = context.boardData.flatMap {
            HitTesting.hitTest(point: point, elements: $0.elements, threshold: 12)?.id
        }
        manager.inProgressConnectorSource = point
        manager.inProgressConnectorTarget = point
        manager.inProgressConnectorColor = context.color
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        manager.inProgressConnectorTarget = point
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        guard let start = startPoint else { cancel(); return }

        let targetElementId = context.boardData.flatMap {
            HitTesting.hitTest(point: point, elements: $0.elements, threshold: 12)?.id
        }

        let sourceSnap = snapToElementEdge(point: start, elementId: sourceElementId, board: context.boardData)
        let targetSnap = snapToElementEdge(point: point, elementId: targetElementId, board: context.boardData)

        let data = ConnectorData(
            sourceElementId: sourceElementId,
            targetElementId: targetElementId,
            sourcePoint: [sourceSnap.x, sourceSnap.y],
            targetPoint: [targetSnap.x, targetSnap.y],
            strokeColor: context.color,
            strokeWidth: context.thickness
        )
        let zIndex = context.boardData?.nextZIndex ?? 0
        context.addElement(Element(type: .connector(data), zIndex: zIndex))

        cancel()
    }

    func cancel() {
        startPoint = nil
        sourceElementId = nil
        manager.inProgressConnectorSource = nil
        manager.inProgressConnectorTarget = nil
    }

    var cursor: NSCursor { .crosshair }

    private func snapToElementEdge(point: CGPoint, elementId: UUID?, board: BoardData?) -> CGPoint {
        guard let board, let id = elementId,
              let element = board.elements.first(where: { $0.id == id }) else { return point }
        let bounds = HitTesting.elementBounds(element)
        let cx = bounds.midX, cy = bounds.midY
        let dx = point.x - cx, dy = point.y - cy
        if abs(dx) < 1 && abs(dy) < 1 { return CGPoint(x: bounds.midX, y: bounds.minY) }

        let angle = atan2(dy, dx)
        let hw = bounds.width / 2, hh = bounds.height / 2
        let edgeAngle = atan2(hh, hw)

        if abs(angle) < edgeAngle {
            return CGPoint(x: bounds.maxX, y: cy + hw * tan(angle))
        } else if abs(angle) > .pi - edgeAngle {
            return CGPoint(x: bounds.minX, y: cy - hw * tan(angle))
        } else if angle > 0 {
            return CGPoint(x: cx + hh / tan(angle), y: bounds.maxY)
        } else {
            return CGPoint(x: cx - hh / tan(angle), y: bounds.minY)
        }
    }
}
