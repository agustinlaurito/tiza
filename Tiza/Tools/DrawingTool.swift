import AppKit

class DrawingTool: Tool {
    var toolType: ToolType { fatalError("Subclasses must override") }
    unowned let manager: ToolManager

    let strokeStyle: StrokeStyle
    let supportsPressure: Bool
    let supportsShapeRecognition: Bool

    private var rawPoints: [CGPoint] = []
    private var rawPressures: [Double] = []

    init(manager: ToolManager, strokeStyle: StrokeStyle,
         supportsPressure: Bool, supportsShapeRecognition: Bool) {
        self.manager = manager
        self.strokeStyle = strokeStyle
        self.supportsPressure = supportsPressure
        self.supportsShapeRecognition = supportsShapeRecognition
    }

    func pointerDown(at point: WorldPoint, context: ToolContext) {
        rawPoints = [point]
        rawPressures = supportsPressure ? [manager.lastEventPressure] : []

        manager.inProgressPoints = rawPoints
        manager.inProgressColor = context.color
        manager.inProgressThickness = context.thickness
        manager.inProgressStyle = strokeStyle
        manager.inProgressPressures = supportsPressure ? rawPressures : nil
    }

    func pointerDragged(to point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        rawPoints.append(snapped)
        if supportsPressure {
            rawPressures.append(manager.lastEventPressure)
            manager.inProgressPressures = rawPressures
        }
        manager.inProgressPoints = rawPoints
    }

    func pointerUp(at point: WorldPoint, context: ToolContext) {
        let snapped = context.constrain(point)
        rawPoints.append(snapped)
        if supportsPressure {
            rawPressures.append(manager.lastEventPressure)
        }

        guard rawPoints.count >= 2 else {
            cancel()
            return
        }

        if supportsShapeRecognition, let shape = ShapeRecognizer.recognize(rawPoints) {
            let shapeData = ShapeData(
                shapeType: shape.type,
                origin: [shape.bounds.origin.x, shape.bounds.origin.y],
                size: [shape.bounds.width, shape.bounds.height],
                rotation: 0,
                strokeColor: context.color,
                fillColor: nil,
                strokeWidth: context.thickness
            )
            let zIndex = context.boardData?.nextZIndex ?? 0
            context.addElement(Element(type: .shape(shapeData), zIndex: zIndex))
        } else {
            let smoothed = StrokeSmoothing.smooth(rawPoints)
            var pressures: [Double]?
            if supportsPressure {
                let hasPressure = rawPressures.contains { $0 > 0 && $0 < 1.0 }
                if hasPressure {
                    pressures = Self.interpolatePressures(rawPressures, from: rawPoints.count, to: smoothed.count)
                }
            }
            let strokeData = StrokeData(
                points: smoothed.map { [$0.x, $0.y] },
                color: context.color,
                thickness: context.thickness,
                style: strokeStyle,
                pressures: pressures
            )
            let zIndex = context.boardData?.nextZIndex ?? 0
            context.addElement(Element(type: .stroke(strokeData), zIndex: zIndex))
        }

        rawPoints = []
        rawPressures = []
        manager.inProgressPoints = []
        manager.inProgressPressures = nil
    }

    func cancel() {
        rawPoints = []
        rawPressures = []
        manager.inProgressPoints = []
        manager.inProgressPressures = nil
    }

    var cursor: NSCursor { .crosshair }

    private static func interpolatePressures(_ pressures: [Double], from: Int, to: Int) -> [Double] {
        guard from > 1, to > 1 else { return Array(repeating: 1.0, count: to) }
        var result: [Double] = []
        for i in 0..<to {
            let t = Double(i) / Double(to - 1) * Double(from - 1)
            let lo = Int(t)
            let hi = min(lo + 1, from - 1)
            let frac = t - Double(lo)
            result.append(pressures[lo] * (1 - frac) + pressures[hi] * frac)
        }
        return result
    }
}
