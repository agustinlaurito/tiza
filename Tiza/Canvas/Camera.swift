import CoreGraphics

struct Camera: Equatable {
    var center: CGPoint = .zero
    var scale: CGFloat = 1.0

    static let minScale: CGFloat = 0.1
    static let maxScale: CGFloat = 10.0

    func worldToScreen(_ worldPoint: WorldPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (worldPoint.x - center.x) * scale + viewSize.width / 2,
            y: (worldPoint.y - center.y) * scale + viewSize.height / 2
        )
    }

    func screenToWorld(_ screenPoint: CGPoint, viewSize: CGSize) -> WorldPoint {
        WorldPoint(
            x: (screenPoint.x - viewSize.width / 2) / scale + center.x,
            y: (screenPoint.y - viewSize.height / 2) / scale + center.y
        )
    }

    func affineTransform(for viewSize: CGSize) -> CGAffineTransform {
        // World → Screen: translate(-center), scale, translate(+viewCenter)
        let tx = -center.x * scale + viewSize.width / 2
        let ty = -center.y * scale + viewSize.height / 2
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }

    func visibleWorldRect(viewSize: CGSize) -> WorldRect {
        let topLeft = screenToWorld(.zero, viewSize: viewSize)
        let bottomRight = screenToWorld(CGPoint(x: viewSize.width, y: viewSize.height), viewSize: viewSize)
        return WorldRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }

    mutating func zoom(by factor: CGFloat, anchor screenAnchor: CGPoint, viewSize: CGSize) {
        let worldAnchor = screenToWorld(screenAnchor, viewSize: viewSize)
        scale = min(max(scale * factor, Camera.minScale), Camera.maxScale)
        // After scaling, the world anchor should still map to the same screen point.
        // screenAnchor = (worldAnchor - newCenter) * newScale + viewSize/2
        // newCenter = worldAnchor - (screenAnchor - viewSize/2) / newScale
        center = CGPoint(
            x: worldAnchor.x - (screenAnchor.x - viewSize.width / 2) / scale,
            y: worldAnchor.y - (screenAnchor.y - viewSize.height / 2) / scale
        )
    }

    mutating func pan(byScreenDelta delta: CGPoint) {
        center = CGPoint(
            x: center.x - delta.x / scale,
            y: center.y - delta.y / scale
        )
    }
}

struct CameraState: Codable, Equatable {
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1.0

    var camera: Camera {
        Camera(center: CGPoint(x: x, y: y), scale: CGFloat(scale))
    }

    init(from camera: Camera) {
        self.x = Double(camera.center.x)
        self.y = Double(camera.center.y)
        self.scale = Double(camera.scale)
    }

    init(x: Double = 0, y: Double = 0, scale: Double = 1.0) {
        self.x = x
        self.y = y
        self.scale = scale
    }
}
