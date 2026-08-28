import AppKit
import CoreGraphics

enum BoardBackgroundRenderer {
    static func draw(_ background: BoardBackground, in context: CGContext,
                     viewSize: CGSize, camera: Camera, appearance: NSAppearance?) {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        switch background {
        case .white:
            context.setFillColor(isDark
                ? CGColor(gray: 0.15, alpha: 1)
                : CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: viewSize))

        case .dark:
            context.setFillColor(isDark
                ? CGColor(gray: 0.10, alpha: 1)
                : CGColor(gray: 0.18, alpha: 1))
            context.fill(CGRect(origin: .zero, size: viewSize))

        case .grid:
            let bgColor = isDark ? CGColor(gray: 0.15, alpha: 1) : CGColor(gray: 1, alpha: 1)
            let lineColor = isDark ? CGColor(gray: 0.22, alpha: 1) : CGColor(gray: 0.88, alpha: 1)
            context.setFillColor(bgColor)
            context.fill(CGRect(origin: .zero, size: viewSize))
            drawGrid(in: context, viewSize: viewSize, camera: camera,
                     spacing: 20, lineColor: lineColor, lineWidth: 0.5)

        case .dottedGrid:
            let bgColor = isDark ? CGColor(gray: 0.15, alpha: 1) : CGColor(gray: 1, alpha: 1)
            let dotColor = isDark ? CGColor(gray: 0.30, alpha: 1) : CGColor(gray: 0.78, alpha: 1)
            context.setFillColor(bgColor)
            context.fill(CGRect(origin: .zero, size: viewSize))
            drawDotGrid(in: context, viewSize: viewSize, camera: camera,
                        spacing: 20, dotColor: dotColor, dotRadius: 1)

        case .lined:
            let bgColor = isDark ? CGColor(gray: 0.15, alpha: 1) : CGColor(gray: 1, alpha: 1)
            let lineColor = isDark ? CGColor(gray: 0.22, alpha: 1) : CGColor(gray: 0.88, alpha: 1)
            context.setFillColor(bgColor)
            context.fill(CGRect(origin: .zero, size: viewSize))
            drawHorizontalLines(in: context, viewSize: viewSize, camera: camera,
                                spacing: 24, lineColor: lineColor, lineWidth: 0.5)
        }
    }

    private static func drawGrid(in ctx: CGContext, viewSize: CGSize, camera: Camera,
                                  spacing: CGFloat, lineColor: CGColor, lineWidth: CGFloat) {
        let screenSpacing = spacing * camera.scale
        guard screenSpacing > 4 else { return }

        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(lineWidth)

        let visibleRect = camera.visibleWorldRect(viewSize: viewSize)
        let startX = floor(visibleRect.minX / spacing) * spacing
        let endX = ceil(visibleRect.maxX / spacing) * spacing
        let startY = floor(visibleRect.minY / spacing) * spacing
        let endY = ceil(visibleRect.maxY / spacing) * spacing

        let transform = camera.affineTransform(for: viewSize)

        var x = startX
        while x <= endX {
            let screenX = CGPoint(x: x, y: 0).applying(transform).x
            ctx.move(to: CGPoint(x: screenX, y: 0))
            ctx.addLine(to: CGPoint(x: screenX, y: viewSize.height))
            x += spacing
        }

        var y = startY
        while y <= endY {
            let screenY = CGPoint(x: 0, y: y).applying(transform).y
            ctx.move(to: CGPoint(x: 0, y: screenY))
            ctx.addLine(to: CGPoint(x: viewSize.width, y: screenY))
            y += spacing
        }

        ctx.strokePath()
    }

    private static func drawDotGrid(in ctx: CGContext, viewSize: CGSize, camera: Camera,
                                     spacing: CGFloat, dotColor: CGColor, dotRadius: CGFloat) {
        let screenSpacing = spacing * camera.scale
        guard screenSpacing > 6 else { return }

        ctx.setFillColor(dotColor)

        let visibleRect = camera.visibleWorldRect(viewSize: viewSize)
        let startX = floor(visibleRect.minX / spacing) * spacing
        let endX = ceil(visibleRect.maxX / spacing) * spacing
        let startY = floor(visibleRect.minY / spacing) * spacing
        let endY = ceil(visibleRect.maxY / spacing) * spacing

        let transform = camera.affineTransform(for: viewSize)

        var y = startY
        while y <= endY {
            var x = startX
            while x <= endX {
                let screen = CGPoint(x: x, y: y).applying(transform)
                ctx.fillEllipse(in: CGRect(
                    x: screen.x - dotRadius,
                    y: screen.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
                x += spacing
            }
            y += spacing
        }
    }

    private static func drawHorizontalLines(in ctx: CGContext, viewSize: CGSize, camera: Camera,
                                             spacing: CGFloat, lineColor: CGColor, lineWidth: CGFloat) {
        let screenSpacing = spacing * camera.scale
        guard screenSpacing > 4 else { return }

        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(lineWidth)

        let visibleRect = camera.visibleWorldRect(viewSize: viewSize)
        let startY = floor(visibleRect.minY / spacing) * spacing
        let endY = ceil(visibleRect.maxY / spacing) * spacing

        let transform = camera.affineTransform(for: viewSize)

        var y = startY
        while y <= endY {
            let screenY = CGPoint(x: 0, y: y).applying(transform).y
            ctx.move(to: CGPoint(x: 0, y: screenY))
            ctx.addLine(to: CGPoint(x: viewSize.width, y: screenY))
            y += spacing
        }

        ctx.strokePath()
    }
}
