import AppKit

final class TextTool: Tool {
    var toolType: ToolType { .text }
    unowned let manager: ToolManager

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        manager.textEditingPosition = point
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {}
    func pointerUp(at point: WorldPoint, context: ToolContext) {}

    func cancel() {
        manager.textEditingPosition = nil
    }

    var cursor: NSCursor { .iBeam }
}
