import AppKit
import CoreGraphics

enum Renderer {
    static func drawElements(_ elements: [Element], in context: CGContext,
                              camera: Camera, viewSize: CGSize,
                              imageCache: [String: NSImage] = [:]) {
        let transform = camera.affineTransform(for: viewSize)
        let visibleWorld = camera.visibleWorldRect(viewSize: viewSize)

        context.saveGState()
        context.concatenate(transform)

        let sorted = elements.sorted { $0.zIndex < $1.zIndex }
        for element in sorted {
            drawElement(element, in: context, visibleWorld: visibleWorld,
                        scale: camera.scale, imageCache: imageCache)
        }

        context.restoreGState()
    }

    private static func drawElement(_ element: Element, in ctx: CGContext,
                                     visibleWorld: WorldRect, scale: CGFloat,
                                     imageCache: [String: NSImage]) {
        switch element.type {
        case .stroke(let data):
            drawStroke(data, in: ctx, scale: scale)
        case .shape(let data):
            drawShape(data, in: ctx, scale: scale)
        case .text(let data):
            drawText(data, in: ctx, scale: scale)
        case .image(let data):
            drawImage(data, in: ctx, scale: scale, imageCache: imageCache)
        }
    }

    // MARK: - In-Progress & Selection Overlays

    static func drawInProgressStroke(points: [CGPoint], color: CodableColor, thickness: Double,
                                      style: StrokeStyle, in context: CGContext,
                                      camera: Camera, viewSize: CGSize) {
        guard points.count >= 2 else { return }
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        let data = StrokeData(
            points: points.map { [$0.x, $0.y] },
            color: color, thickness: thickness, style: style
        )
        drawStroke(data, in: context, scale: camera.scale)

        context.restoreGState()
    }

    static func drawDragRect(_ rect: WorldRect, in context: CGContext,
                              camera: Camera, viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        let lineWidth = 1.0 / camera.scale
        context.setLineWidth(lineWidth)
        context.setLineDash(phase: 0, lengths: [4 / camera.scale, 4 / camera.scale])

        context.setFillColor(NSColor.selectedControlColor.withAlphaComponent(0.08).cgColor)
        context.fill(rect)

        context.setStrokeColor(NSColor.selectedControlColor.cgColor)
        context.stroke(rect)

        context.restoreGState()
    }

    static func drawSelectionHandles(_ bounds: WorldRect, offset: CGPoint,
                                      in context: CGContext, camera: Camera,
                                      viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        let rect = bounds.offsetBy(dx: offset.x, dy: offset.y)
        let padding: CGFloat = 4 / camera.scale
        let padded = rect.insetBy(dx: -padding, dy: -padding)

        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1.0 / camera.scale)
        context.setLineDash(phase: 0, lengths: [])
        context.stroke(padded)

        let handleSize: CGFloat = 6 / camera.scale
        let corners = [
            CGPoint(x: padded.minX, y: padded.minY),
            CGPoint(x: padded.maxX, y: padded.minY),
            CGPoint(x: padded.minX, y: padded.maxY),
            CGPoint(x: padded.maxX, y: padded.maxY),
        ]

        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        for corner in corners {
            let r = CGRect(x: corner.x - handleSize / 2, y: corner.y - handleSize / 2,
                           width: handleSize, height: handleSize)
            context.fillEllipse(in: r)
            context.strokeEllipse(in: r)
        }

        context.restoreGState()
    }

    static func drawInProgressShape(type: ShapeType, origin: CGPoint, size: CGSize,
                                      color: CodableColor, thickness: Double,
                                      in context: CGContext, camera: Camera, viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        let data = ShapeData(
            shapeType: type, origin: [origin.x, origin.y],
            size: [size.width, size.height], rotation: 0,
            strokeColor: color, fillColor: nil, strokeWidth: thickness
        )
        drawShape(data, in: context, scale: camera.scale)

        context.restoreGState()
    }

    // MARK: - Image

    private static func drawImage(_ data: ImageData, in ctx: CGContext, scale: CGFloat,
                                    imageCache: [String: NSImage]) {
        guard let image = imageCache[data.assetId],
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let origin = CGPoint(x: data.origin[0], y: data.origin[1])
        let size = CGSize(width: data.size[0], height: data.size[1])

        ctx.saveGState()

        if data.rotation != 0 {
            let cx = origin.x + size.width / 2
            let cy = origin.y + size.height / 2
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: data.rotation)
            ctx.translateBy(x: -cx, y: -cy)
        }

        ctx.translateBy(x: origin.x, y: origin.y + size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        ctx.restoreGState()
    }

    // MARK: - Stroke

    private static func drawStroke(_ data: StrokeData, in ctx: CGContext, scale: CGFloat) {
        guard data.points.count >= 2 else { return }

        ctx.saveGState()

        let lineWidth = data.thickness / scale
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch data.style {
        case .pen:
            ctx.setStrokeColor(data.color.cgColor)
            ctx.setBlendMode(.normal)
        case .highlighter:
            var color = data.color
            color.a = 0.35
            ctx.setStrokeColor(color.cgColor)
            ctx.setBlendMode(.normal)
            ctx.setLineWidth(lineWidth * 4)
        }

        ctx.beginPath()
        ctx.move(to: CGPoint(x: data.points[0][0], y: data.points[0][1]))
        for i in 1..<data.points.count {
            ctx.addLine(to: CGPoint(x: data.points[i][0], y: data.points[i][1]))
        }
        ctx.strokePath()

        ctx.restoreGState()
    }

    private static func drawShape(_ data: ShapeData, in ctx: CGContext, scale: CGFloat) {
        ctx.saveGState()

        let origin = CGPoint(x: data.origin[0], y: data.origin[1])
        let size = CGSize(width: data.size[0], height: data.size[1])
        let rect = CGRect(origin: origin, size: size)

        if data.rotation != 0 {
            let cx = origin.x + size.width / 2
            let cy = origin.y + size.height / 2
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: data.rotation)
            ctx.translateBy(x: -cx, y: -cy)
        }

        ctx.setLineWidth(data.strokeWidth / scale)

        switch data.shapeType {
        case .rectangle:
            if let fill = data.fillColor {
                ctx.setFillColor(fill.cgColor)
                ctx.fill(rect)
            }
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.stroke(rect)

        case .ellipse:
            if let fill = data.fillColor {
                ctx.setFillColor(fill.cgColor)
                ctx.fillEllipse(in: rect)
            }
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.strokeEllipse(in: rect)

        case .line:
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.setLineCap(.round)
            ctx.move(to: origin)
            ctx.addLine(to: CGPoint(x: origin.x + size.width, y: origin.y + size.height))
            ctx.strokePath()

        case .arrow:
            let start = origin
            let end = CGPoint(x: origin.x + size.width, y: origin.y + size.height)
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.setFillColor(data.strokeColor.cgColor)
            ctx.setLineCap(.round)

            ctx.move(to: start)
            ctx.addLine(to: end)
            ctx.strokePath()

            drawArrowhead(at: end, from: start, in: ctx,
                          size: max(data.strokeWidth * 3 / scale, 8 / scale))
        }

        ctx.restoreGState()
    }

    private static func drawArrowhead(at tip: CGPoint, from tail: CGPoint,
                                       in ctx: CGContext, size: CGFloat) {
        let angle = atan2(tip.y - tail.y, tip.x - tail.x)
        let spread: CGFloat = .pi / 6

        let p1 = CGPoint(
            x: tip.x - size * cos(angle - spread),
            y: tip.y - size * sin(angle - spread)
        )
        let p2 = CGPoint(
            x: tip.x - size * cos(angle + spread),
            y: tip.y - size * sin(angle + spread)
        )

        ctx.beginPath()
        ctx.move(to: tip)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawText(_ data: TextData, in ctx: CGContext, scale: CGFloat) {
        let position = CGPoint(x: data.position[0], y: data.position[1])
        let fontSize = data.fontSize / scale

        ctx.saveGState()

        if data.rotation != 0 {
            ctx.translateBy(x: position.x, y: position.y)
            ctx.rotate(by: data.rotation)
            ctx.translateBy(x: -position.x, y: -position.y)
        }

        let font: NSFont
        if data.bold {
            font = NSFont.boldSystemFont(ofSize: fontSize)
        } else {
            font = NSFont.systemFont(ofSize: fontSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: data.color.nsColor
        ]

        let string = NSAttributedString(string: data.content, attributes: attributes)
        let line = CTLineCreateWithAttributedString(string)

        ctx.textPosition = position
        // Flip for text rendering (Core Graphics text is bottom-up)
        ctx.saveGState()
        ctx.translateBy(x: position.x, y: position.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()

        ctx.restoreGState()
    }
}
