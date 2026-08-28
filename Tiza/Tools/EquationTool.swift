import AppKit

final class EquationTool: Tool {
    var toolType: ToolType { .equation }
    unowned let manager: ToolManager

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        manager.equationEditingPosition = point
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {}
    func pointerUp(at point: WorldPoint, context: ToolContext) {}
    func cancel() {
        manager.equationEditingPosition = nil
    }

    var cursor: NSCursor { .crosshair }
}
