import AppKit

final class HighlighterTool: DrawingTool {
    override var toolType: ToolType { .highlighter }

    init(manager: ToolManager) {
        super.init(manager: manager, strokeStyle: .highlighter,
                   supportsPressure: false, supportsShapeRecognition: false)
    }
}
