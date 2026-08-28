import CoreGraphics

enum StrokeSmoothing {
    static func smooth(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }

        let simplified = ramerDouglasPeucker(points, epsilon: 1.0)
        guard simplified.count >= 3 else { return simplified }

        return catmullRomSpline(simplified, pointsPerSegment: 8)
    }

    // MARK: - Catmull-Rom spline interpolation

    private static func catmullRomSpline(_ points: [CGPoint], pointsPerSegment: Int) -> [CGPoint] {
        var result: [CGPoint] = [points[0]]

        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[min(points.count - 1, i + 1)]
            let p3 = points[min(points.count - 1, i + 2)]

            let segmentLength = p1.distance(to: p2)
            let steps = max(2, min(pointsPerSegment, Int(segmentLength / 2)))

            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                result.append(catmullRomPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t))
            }
        }

        return result
    }

    private static func catmullRomPoint(p0: CGPoint, p1: CGPoint,
                                         p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * ((2 * p1.x) +
                        (-p0.x + p2.x) * t +
                        (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                        (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)

        let y = 0.5 * ((2 * p1.y) +
                        (-p0.y + p2.y) * t +
                        (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                        (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)

        return CGPoint(x: x, y: y)
    }

    // MARK: - Ramer-Douglas-Peucker simplification

    private static func ramerDouglasPeucker(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var maxDist: CGFloat = 0
        var maxIndex = 0

        let first = points[0]
        let last = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = ramerDouglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = ramerDouglasPeucker(Array(points[maxIndex...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    private static func perpendicularDistance(point: CGPoint,
                                               lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy

        guard lengthSq > 0 else { return point.distance(to: lineStart) }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSq))
        let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
        return point.distance(to: projection)
    }
}
