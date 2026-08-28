import AppKit

final class EraserTool: Tool {
    var toolType: ToolType { .eraser }
    unowned let manager: ToolManager
    private var erasedIds: Set<UUID> = []
    private var isGrouping = false
    private weak var activeUndoManager: UndoManager?

    init(manager: ToolManager) {
        self.manager = manager
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        erasedIds = []
        activeUndoManager = context.undoManager
        context.undoManager?.beginUndoGrouping()
        isGrouping = true
        eraseAt(point, context: context)
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        eraseAt(point, context: context)
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        eraseAt(point, context: context)
        if isGrouping {
            context.undoManager?.endUndoGrouping()
            isGrouping = false
        }
        erasedIds = []
        activeUndoManager = nil
    }

    func cancel() {
        if isGrouping {
            activeUndoManager?.endUndoGrouping()
        }
        erasedIds = []
        isGrouping = false
        activeUndoManager = nil
    }

    var cursor: NSCursor {
        NSCursor(image: eraserCursorImage(), hotSpot: NSPoint(x: 8, y: 8))
    }

    private func eraseAt(_ point: WorldPoint, context: ToolContext) {
        guard let board = context.boardData else { return }
        let threshold = HitTesting.defaultThreshold

        for element in board.elements {
            if !erasedIds.contains(element.id),
               HitTesting.isHit(point: point, element: element, threshold: threshold) {
                erasedIds.insert(element.id)
                context.removeElement(id: element.id)
            }
        }
    }

    private func eraserCursorImage() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.controlTextColor.withAlphaComponent(0.6).setStroke()
            NSColor.controlBackgroundColor.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            path.lineWidth = 1.5
            path.fill()
            path.stroke()
            return true
        }
        return image
    }
}
