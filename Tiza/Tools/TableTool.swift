import AppKit

final class TableTool: Tool {
    var toolType: ToolType { .table }
    unowned let manager: ToolManager

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        let data = TableData.empty(
            rows: 3, columns: 3,
            origin: [point.x, point.y],
            color: context.color
        )
        let zIndex = context.boardData?.nextZIndex ?? 0
        context.addElement(Element(type: .table(data), zIndex: zIndex))
        manager.switchTool(.select)
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {}
    func pointerUp(at point: WorldPoint, context: ToolContext) {}
    func cancel() {}

    var cursor: NSCursor { .crosshair }
}
