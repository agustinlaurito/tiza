import AppKit

final class PenTool: DrawingTool {
    override var toolType: ToolType { .pen }

    init(manager: ToolManager) {
        super.init(manager: manager, strokeStyle: .pen,
                   supportsPressure: true, supportsShapeRecognition: true)
    }
}
