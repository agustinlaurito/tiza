import AppKit

final class ShapeTool: Tool {
    let toolType: ToolType
    unowned let manager: ToolManager
    private var startPoint: WorldPoint?

    private var shapeType: ShapeType {
        switch toolType {
        case .line: .line
        case .arrow: .arrow
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        default: .rectangle
        }
    }

    init(type: ToolType, manager: ToolManager) {
        self.toolType = type
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        startPoint = snapped
        updateInProgress(to: snapped, context: context)
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        updateInProgress(to: snapped, context: context)
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        guard let start = startPoint else { return }
        let snapped = context.constrain(point)

        let (origin, size) = computeOriginAndSize(from: start, to: snapped)

        guard max(abs(size.width), abs(size.height)) > 2 else {
            cancel()
            return
        }

        let shapeData = ShapeData(
            shapeType: shapeType,
            origin: [origin.x, origin.y],
            size: [size.width, size.height],
            rotation: 0,
            strokeColor: context.color,
            fillColor: nil,
            strokeWidth: context.thickness
        )

        let zIndex = context.boardData?.nextZIndex ?? 0
        let element = Element(type: .shape(shapeData), zIndex: zIndex)
        context.addElement(element)

        startPoint = nil
        manager.inProgressShapeType = nil
    }

    func cancel() {
        startPoint = nil
        manager.inProgressShapeType = nil
    }

    var cursor: NSCursor { .crosshair }

    private func updateInProgress(to point: WorldPoint, context: ToolContext) {
        guard let start = startPoint else { return }
        let (origin, size) = computeOriginAndSize(from: start, to: point)
        manager.inProgressShapeType = shapeType
        manager.inProgressShapeOrigin = origin
        manager.inProgressShapeSize = size
        manager.inProgressShapeColor = context.color
        manager.inProgressShapeThickness = context.thickness
    }

    private func computeOriginAndSize(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGSize) {
        switch shapeType {
        case .line, .arrow:
            return (start, CGSize(width: end.x - start.x, height: end.y - start.y))
        case .rectangle, .ellipse:
            let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
            let size = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))
            return (origin, size)
        }
    }
}
