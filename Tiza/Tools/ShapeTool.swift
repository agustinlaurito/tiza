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
        var snapped = context.constrain(point)
        if NSEvent.modifierFlags.contains(.shift), let start = startPoint {
            snapped = constrainPoint(snapped, from: start)
        }
        updateInProgress(to: snapped, context: context)
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        guard let start = startPoint else { return }
        var snapped = context.constrain(point)
        if NSEvent.modifierFlags.contains(.shift) {
            snapped = constrainPoint(snapped, from: start)
        }

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

    private func constrainPoint(_ point: CGPoint, from start: CGPoint) -> CGPoint {
        switch shapeType {
        case .line, .arrow:
            let dx = point.x - start.x
            let dy = point.y - start.y
            let angle = atan2(dy, dx)
            let snappedAngle = (angle / (.pi / 4)).rounded() * (.pi / 4)
            let dist = hypot(dx, dy)
            return CGPoint(x: start.x + dist * cos(snappedAngle),
                           y: start.y + dist * sin(snappedAngle))
        case .rectangle, .ellipse:
            let dx = point.x - start.x
            let dy = point.y - start.y
            let side = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + side * (dx < 0 ? -1 : 1),
                           y: start.y + side * (dy < 0 ? -1 : 1))
        }
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
