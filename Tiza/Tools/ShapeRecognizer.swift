import CoreGraphics

struct RecognizedShape {
    let type: ShapeType
    let bounds: CGRect
}

enum ShapeRecognizer {
    static func recognize(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 5 else { return nil }

        let bounds = boundingRect(of: points)
        let minDimension = min(bounds.width, bounds.height)
        guard minDimension > 10 else {
            return recognizeLine(points)
        }

        if let circle = recognizeCircle(points, bounds: bounds) { return circle }
        if let rect = recognizeRectangle(points, bounds: bounds) { return rect }
        if let tri = recognizeTriangle(points, bounds: bounds) { return tri }
        return nil
    }

    private static func recognizeLine(_ points: [CGPoint]) -> RecognizedShape? {
        guard let first = points.first, let last = points.last else { return nil }
        let lineLength = first.distance(to: last)
        guard lineLength > 20 else { return nil }

        let maxDev = points.map { HitTesting.distanceToSegment(point: $0, a: first, b: last) }.max() ?? 0
        if maxDev / lineLength < 0.1 {
            let origin = CGPoint(x: min(first.x, last.x), y: min(first.y, last.y))
            return RecognizedShape(type: .line, bounds: CGRect(
                origin: first,
                size: CGSize(width: last.x - first.x, height: last.y - first.y)))
        }
        return nil
    }

    private static func recognizeCircle(_ points: [CGPoint], bounds: CGRect) -> RecognizedShape? {
        let cx = bounds.midX, cy = bounds.midY
        let avgRadius = points.reduce(0.0) { $0 + hypot($1.x - cx, $1.y - cy) } / CGFloat(points.count)
        guard avgRadius > 5 else { return nil }

        let deviations = points.map { abs(hypot($0.x - cx, $0.y - cy) - avgRadius) / avgRadius }
        let avgDeviation = deviations.reduce(0, +) / CGFloat(deviations.count)

        guard avgDeviation < 0.15 else { return nil }

        guard let first = points.first, let last = points.last else { return nil }
        let closeness = first.distance(to: last) / avgRadius
        guard closeness < 0.5 else { return nil }

        let aspect = bounds.width / bounds.height
        guard aspect > 0.5 && aspect < 2.0 else { return nil }

        let r = avgRadius
        return RecognizedShape(type: .ellipse, bounds: CGRect(
            x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private static func recognizeRectangle(_ points: [CGPoint], bounds: CGRect) -> RecognizedShape? {
        guard let first = points.first, let last = points.last else { return nil }
        let closeness = first.distance(to: last) / max(bounds.width, bounds.height)
        guard closeness < 0.2 else { return nil }

        let corners = findCorners(points, expectedCount: 4)
        guard corners.count == 4 else { return nil }

        let perimeter = pathLength(of: points)
        let expectedPerimeter = 2 * (bounds.width + bounds.height)
        let perimRatio = perimeter / expectedPerimeter
        guard perimRatio > 0.8 && perimRatio < 1.4 else { return nil }

        let area = bounds.width * bounds.height
        let convexArea = convexHullArea(of: points)
        let areaRatio = convexArea / area
        guard areaRatio > 0.75 else { return nil }

        return RecognizedShape(type: .rectangle, bounds: bounds)
    }

    private static func recognizeTriangle(_ points: [CGPoint], bounds: CGRect) -> RecognizedShape? {
        guard let first = points.first, let last = points.last else { return nil }
        let closeness = first.distance(to: last) / max(bounds.width, bounds.height)
        guard closeness < 0.25 else { return nil }

        let corners = findCorners(points, expectedCount: 3)
        guard corners.count == 3 else { return nil }

        return RecognizedShape(type: .triangle, bounds: bounds)
    }

    // MARK: - Helpers

    private static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func pathLength(of points: [CGPoint]) -> CGFloat {
        var total: CGFloat = 0
        for i in 1..<points.count {
            total += points[i - 1].distance(to: points[i])
        }
        return total
    }

    private static func findCorners(_ points: [CGPoint], expectedCount: Int) -> [CGPoint] {
        guard points.count > 10 else { return [] }

        let step = max(points.count / 40, 2)
        var angles: [(Int, CGFloat)] = []

        for i in stride(from: step, to: points.count - step, by: 1) {
            let prev = points[i - step]
            let curr = points[i]
            let next = points[i + step]
            let v1 = CGPoint(x: prev.x - curr.x, y: prev.y - curr.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let dot = v1.x * v2.x + v1.y * v2.y
            let mag = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
            guard mag > 0 else { continue }
            let cosAngle = max(-1, min(1, dot / mag))
            let angle = acos(cosAngle)
            angles.append((i, angle))
        }

        angles.sort { $0.1 < $1.1 }

        var corners: [CGPoint] = []
        let minDist = CGFloat(points.count) / CGFloat(expectedCount * 2)

        for (idx, angle) in angles {
            guard angle < .pi * 0.7 else { continue }
            let tooClose = corners.contains { existing in
                existing.distance(to: points[idx]) < minDist
            }
            if !tooClose {
                corners.append(points[idx])
                if corners.count == expectedCount { break }
            }
        }

        return corners
    }

    private static func convexHullArea(of points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        return abs(area) / 2
    }
}
