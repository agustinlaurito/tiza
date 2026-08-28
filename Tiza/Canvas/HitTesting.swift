import CoreGraphics

enum HitTesting {
    static let defaultThreshold: CGFloat = 6.0

    static func hitTest(point: WorldPoint, elements: [Element],
                        threshold: CGFloat = defaultThreshold) -> Element? {
        for element in elements.sorted(by: { $0.zIndex > $1.zIndex }) {
            if isHit(point: point, element: element, threshold: threshold) {
                return element
            }
        }
        return nil
    }

    static func elementsInRect(_ rect: WorldRect, elements: [Element]) -> [Element] {
        elements.filter { elementIntersectsRect(element: $0, rect: rect) }
    }

    static func elementsFullyInRect(_ rect: WorldRect, elements: [Element]) -> [Element] {
        elements.filter { rect.contains(elementBounds($0)) }
    }

    static func isHit(point: WorldPoint, element: Element, threshold: CGFloat) -> Bool {
        switch element.type {
        case .stroke(let data):
            return strokeHitTest(point: point, data: data, threshold: threshold)
        case .shape(let data):
            return shapeHitTest(point: point, data: data, threshold: threshold)
        case .text(let data):
            return textHitTest(point: point, data: data)
        case .image(let data):
            return imageHitTest(point: point, data: data)
        case .connector(let data):
            return connectorHitTest(point: point, data: data, threshold: threshold)
        case .table(let data):
            return tableHitTest(point: point, data: data)
        case .equation(let data):
            return equationHitTest(point: point, data: data)
        }
    }

    // MARK: - Stroke

    private static func strokeHitTest(point: WorldPoint, data: StrokeData,
                                       threshold: CGFloat) -> Bool {
        let totalThreshold = threshold + data.thickness / 2
        guard data.points.count >= 2 else {
            if let first = data.points.first {
                return point.distance(to: CGPoint(x: first[0], y: first[1])) < totalThreshold
            }
            return false
        }

        for i in 0..<(data.points.count - 1) {
            let a = CGPoint(x: data.points[i][0], y: data.points[i][1])
            let b = CGPoint(x: data.points[i + 1][0], y: data.points[i + 1][1])
            if distanceToSegment(point: point, a: a, b: b) < totalThreshold {
                return true
            }
        }
        return false
    }

    // MARK: - Shape

    private static func shapeHitTest(point: WorldPoint, data: ShapeData,
                                      threshold: CGFloat) -> Bool {
        let rect = CGRect(x: data.origin[0], y: data.origin[1],
                          width: data.size[0], height: data.size[1])
        let expanded = rect.insetBy(dx: -threshold, dy: -threshold)

        if data.rotation != 0 {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let rotated = rotatePoint(point, around: center, by: -data.rotation)
            return expanded.contains(rotated)
        }

        return expanded.contains(point)
    }

    // MARK: - Text

    private static func textHitTest(point: WorldPoint, data: TextData) -> Bool {
        let origin = CGPoint(x: data.position[0], y: data.position[1])
        let estimatedWidth = CGFloat(data.content.count) * data.fontSize * 0.6
        let estimatedHeight = data.fontSize * 1.4
        let rect = CGRect(x: origin.x, y: origin.y - estimatedHeight,
                          width: max(estimatedWidth, 20), height: estimatedHeight)
        return rect.contains(point)
    }

    // MARK: - Image

    private static func imageHitTest(point: WorldPoint, data: ImageData) -> Bool {
        let rect = CGRect(x: data.origin[0], y: data.origin[1],
                          width: data.size[0], height: data.size[1])
        if data.rotation != 0 {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let rotated = rotatePoint(point, around: center, by: -data.rotation)
            return rect.contains(rotated)
        }
        return rect.contains(point)
    }

    // MARK: - Connector

    private static func connectorHitTest(point: WorldPoint, data: ConnectorData,
                                          threshold: CGFloat) -> Bool {
        let a = CGPoint(x: data.sourcePoint[0], y: data.sourcePoint[1])
        let b = CGPoint(x: data.targetPoint[0], y: data.targetPoint[1])
        return distanceToSegment(point: point, a: a, b: b) < threshold + data.strokeWidth / 2
    }

    // MARK: - Table

    private static func tableHitTest(point: WorldPoint, data: TableData) -> Bool {
        let w = Double(data.columns) * data.cellWidth
        let h = Double(data.rows) * data.cellHeight
        let rect = CGRect(x: data.origin[0], y: data.origin[1], width: w, height: h)
        return rect.contains(point)
    }

    // MARK: - Equation

    private static func equationHitTest(point: WorldPoint, data: EquationData) -> Bool {
        let bounds = CGRect(x: data.position[0], y: data.position[1] - data.fontSize * 1.4,
                            width: max(CGFloat(data.latex.count) * data.fontSize * 0.55, 30),
                            height: data.fontSize * 1.6)
        return bounds.contains(point)
    }

    // MARK: - Rect intersection

    private static func elementIntersectsRect(element: Element, rect: WorldRect) -> Bool {
        let bounds = elementBounds(element)
        return rect.intersects(bounds)
    }

    static func elementBounds(_ element: Element) -> WorldRect {
        switch element.type {
        case .stroke(let data):
            guard let first = data.points.first else { return .zero }
            var minX = first[0], minY = first[1]
            var maxX = first[0], maxY = first[1]
            for p in data.points {
                minX = min(minX, p[0]); minY = min(minY, p[1])
                maxX = max(maxX, p[0]); maxY = max(maxY, p[1])
            }
            let pad = data.thickness / 2
            return CGRect(x: minX - pad, y: minY - pad,
                          width: maxX - minX + data.thickness,
                          height: maxY - minY + data.thickness)

        case .shape(let data):
            return CGRect(x: data.origin[0], y: data.origin[1],
                          width: data.size[0], height: data.size[1])

        case .text(let data):
            if let width = data.width {
                let lines = max(ceil(CGFloat(data.content.count) * data.fontSize * 0.6 / width), 1)
                let h = data.fontSize * 1.4 * lines
                return CGRect(x: data.position[0], y: data.position[1] - data.fontSize * 1.4,
                              width: width, height: h)
            }
            let w = max(CGFloat(data.content.count) * data.fontSize * 0.6, 20)
            return CGRect(x: data.position[0], y: data.position[1] - data.fontSize * 1.4,
                          width: w, height: data.fontSize * 1.4)

        case .image(let data):
            return CGRect(x: data.origin[0], y: data.origin[1],
                          width: data.size[0], height: data.size[1])

        case .connector(let data):
            let x1 = data.sourcePoint[0], y1 = data.sourcePoint[1]
            let x2 = data.targetPoint[0], y2 = data.targetPoint[1]
            let pad = max(data.strokeWidth, 4.0)
            return CGRect(x: min(x1, x2) - pad, y: min(y1, y2) - pad,
                          width: abs(x2 - x1) + pad * 2, height: abs(y2 - y1) + pad * 2)

        case .table(let data):
            let w = Double(data.columns) * data.cellWidth
            let h = Double(data.rows) * data.cellHeight
            return CGRect(x: data.origin[0], y: data.origin[1], width: w, height: h)

        case .equation(let data):
            let w = max(CGFloat(data.latex.count) * data.fontSize * 0.55, 30)
            return CGRect(x: data.position[0], y: data.position[1] - data.fontSize * 1.4,
                          width: w, height: data.fontSize * 1.6)
        }
    }

    // MARK: - Resize Handle Hit Testing

    enum HandlePosition: Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
        case startPoint, endPoint
    }

    static func hitTestHandle(point: WorldPoint, bounds: WorldRect,
                               handleSize: CGFloat) -> HandlePosition? {
        let padding: CGFloat = 4
        let padded = bounds.insetBy(dx: -padding, dy: -padding)
        let hs = handleSize / 2

        let corners: [(HandlePosition, CGPoint)] = [
            (.topLeft, CGPoint(x: padded.minX, y: padded.minY)),
            (.topRight, CGPoint(x: padded.maxX, y: padded.minY)),
            (.bottomLeft, CGPoint(x: padded.minX, y: padded.maxY)),
            (.bottomRight, CGPoint(x: padded.maxX, y: padded.maxY)),
        ]

        for (pos, center) in corners {
            let hitRect = CGRect(x: center.x - hs, y: center.y - hs,
                                 width: handleSize, height: handleSize)
            if hitRect.contains(point) {
                return pos
            }
        }
        return nil
    }

    static func hitTestLineEndpoint(point: WorldPoint, element: Element,
                                      handleSize: CGFloat) -> HandlePosition? {
        let hs = handleSize / 2
        switch element.type {
        case .shape(let data) where data.shapeType == .line || data.shapeType == .arrow:
            let start = CGPoint(x: data.origin[0], y: data.origin[1])
            let end = CGPoint(x: data.origin[0] + data.size[0], y: data.origin[1] + data.size[1])
            if CGRect(x: start.x - hs, y: start.y - hs, width: handleSize, height: handleSize).contains(point) {
                return .startPoint
            }
            if CGRect(x: end.x - hs, y: end.y - hs, width: handleSize, height: handleSize).contains(point) {
                return .endPoint
            }
        case .connector(let data):
            let start = CGPoint(x: data.sourcePoint[0], y: data.sourcePoint[1])
            let end = CGPoint(x: data.targetPoint[0], y: data.targetPoint[1])
            if CGRect(x: start.x - hs, y: start.y - hs, width: handleSize, height: handleSize).contains(point) {
                return .startPoint
            }
            if CGRect(x: end.x - hs, y: end.y - hs, width: handleSize, height: handleSize).contains(point) {
                return .endPoint
            }
        default:
            break
        }
        return nil
    }

    static func isLineElement(_ element: Element) -> Bool {
        switch element.type {
        case .shape(let data): data.shapeType == .line || data.shapeType == .arrow
        case .connector: true
        default: false
        }
    }

    // MARK: - Geometry helpers

    static func distanceToSegment(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let ab = b - a
        let ap = point - a
        let lengthSq = ab.x * ab.x + ab.y * ab.y
        guard lengthSq > 0 else { return point.distance(to: a) }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSq))
        let projection = CGPoint(x: a.x + t * ab.x, y: a.y + t * ab.y)
        return point.distance(to: projection)
    }

    static func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: Double) -> CGPoint {
        let cos = cos(angle)
        let sin = sin(angle)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * cos - dy * sin,
            y: center.y + dx * sin + dy * cos
        )
    }
}
