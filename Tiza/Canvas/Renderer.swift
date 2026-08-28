import AppKit
import CoreGraphics

enum Renderer {
    static func drawElements(_ elements: [Element], in context: CGContext,
                              camera: Camera, viewSize: CGSize,
                              imageCache: [String: NSImage] = [:],
                              selectedIds: Set<UUID> = [],
                              moveDelta: CGPoint = .zero,
                              animatingOffsets: [UUID: CGPoint] = [:]) {
        let transform = camera.affineTransform(for: viewSize)

        context.saveGState()
        context.concatenate(transform)

        let sorted = elements.sorted { $0.zIndex < $1.zIndex }
        for element in sorted {
            let alignOffset = animatingOffsets[element.id] ?? .zero
            var dx = alignOffset.x
            var dy = alignOffset.y

            if selectedIds.contains(element.id) {
                dx += moveDelta.x
                dy += moveDelta.y
            }

            if dx != 0 || dy != 0 {
                context.saveGState()
                context.translateBy(x: dx, y: dy)
                drawElement(element, in: context, scale: camera.scale, imageCache: imageCache)
                context.restoreGState()
            } else {
                drawElement(element, in: context, scale: camera.scale, imageCache: imageCache)
            }
        }

        context.restoreGState()
    }

    static func drawDeletingElements(_ elements: [ToolManager.DeletingElement],
                                      in context: CGContext, camera: Camera,
                                      viewSize: CGSize, imageCache: [String: NSImage] = [:]) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        for deleting in elements {
            let eased = 1.0 - pow(1.0 - deleting.progress, 2)
            let scale = max(1.0 - eased, 0.001)
            let opacity = max(1.0 - eased, 0)

            context.saveGState()
            context.setAlpha(opacity)
            context.translateBy(x: deleting.center.x, y: deleting.center.y)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -deleting.center.x, y: -deleting.center.y)
            drawElement(deleting.element, in: context, scale: camera.scale, imageCache: imageCache)
            context.restoreGState()
        }

        context.restoreGState()
    }

    static func drawElement(_ element: Element, in ctx: CGContext,
                             scale: CGFloat,
                             imageCache: [String: NSImage]) {
        let hasOpacity = element.opacity < 1.0
        if hasOpacity {
            ctx.saveGState()
            ctx.setAlpha(element.opacity)
        }

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

        if hasOpacity {
            ctx.restoreGState()
        }

        if element.locked {
            drawLockedIndicator(element, in: ctx, scale: scale)
        }
    }

    // MARK: - In-Progress & Selection Overlays

    static func drawSmartGuides(_ guides: [ToolManager.SmartGuide], in context: CGContext,
                                 camera: Camera, viewSize: CGSize) {
        guard !guides.isEmpty else { return }
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        context.setStrokeColor(NSColor.systemPink.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(0.5 / camera.scale)
        context.setLineDash(phase: 0, lengths: [4 / camera.scale, 3 / camera.scale])

        let extent: CGFloat = 50000
        for guide in guides {
            switch guide.orientation {
            case .horizontal:
                context.move(to: CGPoint(x: -extent, y: guide.position))
                context.addLine(to: CGPoint(x: extent, y: guide.position))
            case .vertical:
                context.move(to: CGPoint(x: guide.position, y: -extent))
                context.addLine(to: CGPoint(x: guide.position, y: extent))
            }
        }
        context.strokePath()
        context.restoreGState()
    }

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

    static func drawDragRect(_ rect: WorldRect, crossing: Bool, in context: CGContext,
                              camera: Camera, viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        let lineWidth = 1.0 / camera.scale
        context.setLineWidth(lineWidth)

        if crossing {
            context.setLineDash(phase: 0, lengths: [4 / camera.scale, 4 / camera.scale])
            context.setFillColor(NSColor.systemGreen.withAlphaComponent(0.06).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.7).cgColor)
        } else {
            context.setLineDash(phase: 0, lengths: [])
            context.setFillColor(NSColor.selectedControlColor.withAlphaComponent(0.08).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.selectedControlColor.cgColor)
        }
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

    private static func drawLockedIndicator(_ element: Element, in ctx: CGContext, scale: CGFloat) {
        let bounds = HitTesting.elementBounds(element)
        let iconSize: CGFloat = 12 / scale
        let x = bounds.maxX - iconSize - 2 / scale
        let y = bounds.minY + 2 / scale

        ctx.saveGState()
        ctx.setAlpha(0.5)
        ctx.setFillColor(NSColor.secondaryLabelColor.cgColor)

        let bodyRect = CGRect(x: x + iconSize * 0.15, y: y + iconSize * 0.45,
                              width: iconSize * 0.7, height: iconSize * 0.5)
        ctx.fill(bodyRect)

        ctx.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        ctx.setLineWidth(1.5 / scale)
        let shackle = CGRect(x: x + iconSize * 0.25, y: y + iconSize * 0.05,
                             width: iconSize * 0.5, height: iconSize * 0.45)
        ctx.strokeEllipse(in: shackle)

        ctx.restoreGState()
    }

    private static func applyDashStyle(_ dashStyle: DashStyle, in ctx: CGContext, scale: CGFloat) {
        switch dashStyle {
        case .solid:
            ctx.setLineDash(phase: 0, lengths: [])
        case .dashed:
            ctx.setLineDash(phase: 0, lengths: [8 / scale, 4 / scale])
        case .dotted:
            ctx.setLineDash(phase: 0, lengths: [2 / scale, 3 / scale])
        }
    }

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

        applyDashStyle(data.dashStyle, in: ctx, scale: scale)

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
        applyDashStyle(data.dashStyle, in: ctx, scale: scale)

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

        case .triangle:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            if let fill = data.fillColor {
                ctx.setFillColor(fill.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            }
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.addPath(path)
            ctx.strokePath()

        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            if let fill = data.fillColor {
                ctx.setFillColor(fill.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            }
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.addPath(path)
            ctx.strokePath()

        case .star:
            let path = starPath(in: rect, points: 5)
            if let fill = data.fillColor {
                ctx.setFillColor(fill.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            }
            ctx.setStrokeColor(data.strokeColor.cgColor)
            ctx.addPath(path)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private static func starPath(in rect: CGRect, points: Int) -> CGPath {
        let path = CGMutablePath()
        let cx = rect.midX, cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.38
        let totalPoints = points * 2
        let startAngle = -CGFloat.pi / 2

        for i in 0..<totalPoints {
            let angle = startAngle + CGFloat(i) * .pi / CGFloat(points)
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
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

    static func fontForTextData(_ data: TextData, scale: CGFloat) -> NSFont {
        let fontSize = data.fontSize / scale
        let weight: NSFont.Weight = data.bold ? .bold : .regular

        let baseFont = NSFont.systemFont(ofSize: fontSize, weight: weight)

        let design: NSFontDescriptor.SystemDesign
        switch data.fontStyle {
        case .system: design = .default
        case .serif: design = .serif
        case .rounded: design = .rounded
        }

        if let descriptor = baseFont.fontDescriptor.withDesign(design) {
            return NSFont(descriptor: descriptor, size: fontSize) ?? baseFont
        }
        return baseFont
    }

    private static func drawText(_ data: TextData, in ctx: CGContext, scale: CGFloat) {
        let position = CGPoint(x: data.position[0], y: data.position[1])

        ctx.saveGState()

        if data.rotation != 0 {
            ctx.translateBy(x: position.x, y: position.y)
            ctx.rotate(by: data.rotation)
            ctx.translateBy(x: -position.x, y: -position.y)
        }

        let font = fontForTextData(data, scale: scale)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: data.color.nsColor
        ]
        if data.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = data.color.nsColor
        }

        let string = NSAttributedString(string: data.content, attributes: attributes)
        let line = CTLineCreateWithAttributedString(string)

        ctx.textPosition = position
        ctx.saveGState()
        ctx.translateBy(x: position.x, y: position.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()

        ctx.restoreGState()
    }
}
