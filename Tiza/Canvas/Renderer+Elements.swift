import AppKit
import CoreGraphics

extension Renderer {

    // MARK: - Image

    static func drawImage(_ data: ImageData, in ctx: CGContext, scale: CGFloat,
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

    // MARK: - Locked Indicator

    static func drawLockedIndicator(_ element: Element, in ctx: CGContext, scale: CGFloat) {
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

    // MARK: - Dash Style

    static func applyDashStyle(_ dashStyle: DashStyle, in ctx: CGContext, scale: CGFloat) {
        switch dashStyle {
        case .solid:
            ctx.setLineDash(phase: 0, lengths: [])
        case .dashed:
            ctx.setLineDash(phase: 0, lengths: [8 / scale, 4 / scale])
        case .dotted:
            ctx.setLineDash(phase: 0, lengths: [2 / scale, 3 / scale])
        }
    }

    // MARK: - Stroke

    static func drawStroke(_ data: StrokeData, in ctx: CGContext, scale: CGFloat) {
        guard data.points.count >= 2 else { return }

        ctx.saveGState()

        let baseLineWidth = data.thickness / scale

        switch data.style {
        case .pen:
            ctx.setStrokeColor(data.color.cgColor)
            ctx.setBlendMode(.normal)
        case .highlighter:
            var color = data.color
            color.a = 0.35
            ctx.setStrokeColor(color.cgColor)
            ctx.setBlendMode(.normal)
        }

        let widthMultiplier: CGFloat = data.style == .highlighter ? 4.0 : 1.0

        if let pressures = data.pressures, pressures.count == data.points.count {
            ctx.setLineCap(.round)
            for i in 0..<(data.points.count - 1) {
                let p = max(pressures[i], 0.1)
                let w = baseLineWidth * widthMultiplier * p
                ctx.setLineWidth(w)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: data.points[i][0], y: data.points[i][1]))
                ctx.addLine(to: CGPoint(x: data.points[i + 1][0], y: data.points[i + 1][1]))
                ctx.strokePath()
            }
        } else {
            ctx.setLineWidth(baseLineWidth * widthMultiplier)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            applyDashStyle(data.dashStyle, in: ctx, scale: scale)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: data.points[0][0], y: data.points[0][1]))
            for i in 1..<data.points.count {
                ctx.addLine(to: CGPoint(x: data.points[i][0], y: data.points[i][1]))
            }
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    // MARK: - Shape

    static func drawShape(_ data: ShapeData, in ctx: CGContext, scale: CGFloat) {
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

    static func starPath(in rect: CGRect, points: Int) -> CGPath {
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

    static func drawArrowhead(at tip: CGPoint, from tail: CGPoint,
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

    // MARK: - Text

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

    static func drawText(_ data: TextData, in ctx: CGContext, scale: CGFloat) {
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

        if let width = data.width, data.content.contains("\n") || data.content.count > 5 {
            let framesetter = CTFramesetterCreateWithAttributedString(string)
            let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter, CFRange(location: 0, length: 0),
                nil, CGSize(width: width / scale, height: CGFloat.greatestFiniteMagnitude), nil
            )
            let framePath = CGPath(rect: CGRect(origin: .zero, size: suggestedSize), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)

            ctx.saveGState()
            ctx.translateBy(x: position.x, y: position.y)
            ctx.scaleBy(x: 1, y: -1)
            ctx.translateBy(x: 0, y: -suggestedSize.height)
            CTFrameDraw(frame, ctx)
            ctx.restoreGState()
        } else {
            let line = CTLineCreateWithAttributedString(string)
            ctx.saveGState()
            ctx.translateBy(x: position.x, y: position.y)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = .zero
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }

    // MARK: - Connector

    static func drawConnector(_ data: ConnectorData, in ctx: CGContext, scale: CGFloat) {
        let source = CGPoint(x: data.sourcePoint[0], y: data.sourcePoint[1])
        let target = CGPoint(x: data.targetPoint[0], y: data.targetPoint[1])

        ctx.saveGState()
        ctx.setStrokeColor(data.strokeColor.cgColor)
        ctx.setFillColor(data.strokeColor.cgColor)
        ctx.setLineWidth(data.strokeWidth / scale)
        ctx.setLineCap(.round)
        applyDashStyle(data.dashStyle, in: ctx, scale: scale)

        ctx.beginPath()
        if data.lineType == .curved {
            let midY = (source.y + target.y) / 2
            ctx.move(to: source)
            ctx.addCurve(to: target,
                         control1: CGPoint(x: source.x, y: midY),
                         control2: CGPoint(x: target.x, y: midY))
        } else {
            ctx.move(to: source)
            ctx.addLine(to: target)
        }
        ctx.strokePath()

        let arrowSize = max(data.strokeWidth * 3 / scale, 8 / scale)
        if data.hasTargetArrow {
            drawArrowhead(at: target, from: source, in: ctx, size: arrowSize)
        }
        if data.hasSourceArrow {
            drawArrowhead(at: source, from: target, in: ctx, size: arrowSize)
        }

        ctx.restoreGState()
    }

    // MARK: - Table

    static func drawTable(_ data: TableData, in ctx: CGContext, scale: CGFloat) {
        let origin = CGPoint(x: data.origin[0], y: data.origin[1])
        let cellW = data.cellWidth / scale
        let cellH = data.cellHeight / scale
        let totalW = CGFloat(data.columns) * cellW
        let totalH = CGFloat(data.rows) * cellH

        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: 1.0 / scale, y: 1.0 / scale)

        if data.headerRow, data.rows > 0 {
            ctx.setFillColor(data.strokeColor.cgColor.copy(alpha: 0.08)!)
            ctx.fill(CGRect(x: 0, y: 0, width: totalW * scale, height: cellH * scale))
        }

        ctx.setStrokeColor(data.strokeColor.cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineDash(phase: 0, lengths: [])

        for row in 0...data.rows {
            let y = CGFloat(row) * cellH * scale
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: totalW * scale, y: y))
        }
        for col in 0...data.columns {
            let x = CGFloat(col) * cellW * scale
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: totalH * scale))
        }
        ctx.strokePath()

        let fontSize = data.fontSize
        let font = NSFont.systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: data.strokeColor.nsColor
        ]

        for row in 0..<data.rows {
            for col in 0..<data.columns {
                let cellText = data.cells[row][col]
                guard !cellText.isEmpty else { continue }
                let attrStr = NSAttributedString(string: cellText, attributes: textAttributes)
                let line = CTLineCreateWithAttributedString(attrStr)

                let x = CGFloat(col) * cellW * scale + 4
                let y = CGFloat(row) * cellH * scale + cellH * scale / 2 + fontSize / 3

                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.scaleBy(x: 1, y: -1)
                ctx.textPosition = .zero
                CTLineDraw(line, ctx)
                ctx.restoreGState()
            }
        }

        ctx.restoreGState()
    }

    // MARK: - Equation

    static func drawEquation(_ data: EquationData, in ctx: CGContext, scale: CGFloat) {
        let position = CGPoint(x: data.position[0], y: data.position[1])
        let fontSize = data.fontSize / scale
        let rendered = LatexRenderer.render(data.latex)

        let font = NSFont(name: "STIXTwoMath-Regular", size: fontSize)
                   ?? NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: data.color.nsColor
        ]

        let attrStr = NSAttributedString(string: rendered, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)

        ctx.saveGState()
        ctx.translateBy(x: position.x, y: position.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
