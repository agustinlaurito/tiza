import AppKit

final class HighlighterTool: Tool {
    var toolType: ToolType { .highlighter }
    unowned let manager: ToolManager
    private var rawPoints: [CGPoint] = []

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        rawPoints = [point]
        manager.inProgressPoints = rawPoints
        manager.inProgressColor = context.color
        manager.inProgressThickness = context.thickness
        manager.inProgressStyle = .highlighter
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        rawPoints.append(snapped)
        manager.inProgressPoints = rawPoints
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        rawPoints.append(snapped)
        guard rawPoints.count >= 2 else { cancel(); return }

        let smoothed = StrokeSmoothing.smooth(rawPoints)
        let strokeData = StrokeData(
            points: smoothed.map { [$0.x, $0.y] },
            color: context.color,
            thickness: context.thickness,
            style: .highlighter
        )

        let zIndex = context.boardData?.nextZIndex ?? 0
        let element = Element(type: .stroke(strokeData), zIndex: zIndex)
        context.addElement(element)

        rawPoints = []
        manager.inProgressPoints = []
    }

    func cancel() {
        rawPoints = []
        manager.inProgressPoints = []
    }

    var cursor: NSCursor { .crosshair }
}
