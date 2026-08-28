import AppKit
import CoreGraphics

enum PresentationRenderer {
    static func drawLaser(_ pm: PresentationManager, in ctx: CGContext,
                          camera: Camera, viewSize: CGSize) {
        let now = CACurrentMediaTime()
        let transform = camera.affineTransform(for: viewSize)
        let invScale = 1.0 / camera.scale

        ctx.saveGState()
        ctx.concatenate(transform)

        for point in pm.laserTrail {
            let age = now - point.time
            let alpha = max(0, 1.0 - age / pm.trailDuration)
            let r = 4.0 * alpha * invScale

            ctx.setFillColor(CGColor(red: 1, green: 0.15, blue: 0.1, alpha: alpha * 0.65))
            ctx.fillEllipse(in: CGRect(x: point.position.x - r, y: point.position.y - r,
                                       width: r * 2, height: r * 2))
        }

        if pm.laserActive, let pos = pm.laserPosition {
            let r = 6 * invScale

            ctx.setFillColor(CGColor(red: 1, green: 0.2, blue: 0.15, alpha: 0.2))
            ctx.fillEllipse(in: CGRect(x: pos.x - r * 3, y: pos.y - r * 3,
                                       width: r * 6, height: r * 6))

            ctx.setFillColor(CGColor(red: 1, green: 0.1, blue: 0.05, alpha: 0.9))
            ctx.fillEllipse(in: CGRect(x: pos.x - r, y: pos.y - r,
                                       width: r * 2, height: r * 2))

            let cr = r * 0.4
            ctx.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.6, alpha: 1.0))
            ctx.fillEllipse(in: CGRect(x: pos.x - cr, y: pos.y - cr,
                                       width: cr * 2, height: cr * 2))
        }

        ctx.restoreGState()
    }

    static func drawSpotlight(at screenPos: CGPoint?, radius: CGFloat,
                               in ctx: CGContext, viewSize: CGSize) {
        guard let pos = screenPos else { return }

        ctx.saveGState()

        let path = CGMutablePath()
        path.addRect(CGRect(origin: .zero, size: viewSize))
        path.addEllipse(in: CGRect(x: pos.x - radius, y: pos.y - radius,
                                    width: radius * 2, height: radius * 2))

        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
        ctx.drawPath(using: .eoFill)

        ctx.restoreGState()
    }
}
