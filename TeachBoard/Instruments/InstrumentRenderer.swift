import AppKit
import CoreGraphics

enum InstrumentRenderer {
    static func drawInstruments(_ instruments: [InstrumentState], in ctx: CGContext,
                                 camera: Camera, viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)

        for instrument in instruments {
            ctx.saveGState()
            ctx.concatenate(transform)
            ctx.translateBy(x: instrument.center.x, y: instrument.center.y)
            ctx.rotate(by: instrument.angle)

            let invScale = 1.0 / camera.scale

            switch instrument.kind {
            case .ruler:
                drawRuler(in: ctx, invScale: invScale)
            case .protractor:
                drawProtractor(in: ctx, invScale: invScale)
            }

            ctx.restoreGState()
        }
    }

    // MARK: - Ruler

    private static func drawRuler(in ctx: CGContext, invScale: CGFloat) {
        let halfLength = InstrumentState.rulerLength / 2
        let halfWidth = InstrumentState.rulerWidth / 2
        let bodyRect = CGRect(x: -halfLength, y: -halfWidth,
                              width: InstrumentState.rulerLength, height: InstrumentState.rulerWidth)

        ctx.saveGState()

        let bodyColor = NSColor.systemBlue.withAlphaComponent(0.06).cgColor
        ctx.setFillColor(bodyColor)
        ctx.fill(bodyRect)

        let borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
        ctx.setStrokeColor(borderColor)
        ctx.setLineWidth(1.5 * invScale)
        ctx.stroke(bodyRect)

        let edgeColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        ctx.setStrokeColor(edgeColor)
        ctx.setLineWidth(2.0 * invScale)
        ctx.move(to: CGPoint(x: -halfLength, y: halfWidth))
        ctx.addLine(to: CGPoint(x: halfLength, y: halfWidth))
        ctx.strokePath()

        let tickColor = NSColor.labelColor.withAlphaComponent(0.55).cgColor
        ctx.setStrokeColor(tickColor)

        let spacing: CGFloat = 10
        let totalTicks = Int(InstrumentState.rulerLength / spacing)

        for i in 0...totalTicks {
            let x = -halfLength + CGFloat(i) * spacing
            let tickIndex = i

            let tickLength: CGFloat
            let tickWidth: CGFloat

            if tickIndex % 10 == 0 {
                tickLength = 16
                tickWidth = 1.2 * invScale
            } else if tickIndex % 5 == 0 {
                tickLength = 10
                tickWidth = 0.8 * invScale
            } else {
                tickLength = 5
                tickWidth = 0.5 * invScale
            }

            ctx.setLineWidth(tickWidth)
            ctx.move(to: CGPoint(x: x, y: halfWidth))
            ctx.addLine(to: CGPoint(x: x, y: halfWidth - tickLength))
            ctx.strokePath()
        }

        let font = CTFontCreateWithName("Helvetica Neue" as CFString, 9, nil)
        let textColor = NSColor.labelColor.withAlphaComponent(0.6)

        for i in stride(from: 0, through: totalTicks, by: 10) {
            let x = -halfLength + CGFloat(i) * spacing
            let value = i * Int(spacing)
            let text = "\(value)"

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font as Any,
                .foregroundColor: textColor
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let line = CTLineCreateWithAttributedString(attrStr)
            let textBounds = CTLineGetBoundsWithOptions(line, [])

            ctx.saveGState()
            ctx.translateBy(x: x - textBounds.width / 2, y: halfWidth - 20)
            ctx.scaleBy(x: 1, y: -1)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        drawRotationHandle(in: ctx, at: CGPoint(x: halfLength + 4, y: 0), invScale: invScale,
                           color: NSColor.systemBlue)

        ctx.restoreGState()
    }

    // MARK: - Protractor

    private static func drawProtractor(in ctx: CGContext, invScale: CGFloat) {
        let radius = InstrumentState.protractorRadius

        ctx.saveGState()

        let bodyColor = NSColor.systemOrange.withAlphaComponent(0.05).cgColor
        ctx.setFillColor(bodyColor)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -radius, y: 0))
        ctx.addArc(center: .zero, radius: radius, startAngle: .pi, endAngle: 2 * .pi,
                   clockwise: false)
        ctx.closePath()
        ctx.fillPath()

        let arcColor = NSColor.systemOrange.withAlphaComponent(0.4).cgColor
        ctx.setStrokeColor(arcColor)
        ctx.setLineWidth(1.5 * invScale)
        ctx.beginPath()
        ctx.addArc(center: .zero, radius: radius, startAngle: .pi, endAngle: 2 * .pi,
                   clockwise: false)
        ctx.strokePath()

        let baseColor = NSColor.systemOrange.withAlphaComponent(0.35).cgColor
        ctx.setStrokeColor(baseColor)
        ctx.setLineWidth(1.5 * invScale)
        ctx.move(to: CGPoint(x: -radius, y: 0))
        ctx.addLine(to: CGPoint(x: radius, y: 0))
        ctx.strokePath()

        let tickColor = NSColor.labelColor.withAlphaComponent(0.5).cgColor
        ctx.setStrokeColor(tickColor)

        for deg in 0...180 {
            let angleRad = .pi + Double(deg) * .pi / 180.0

            let tickLength: CGFloat
            let tickWidth: CGFloat

            if deg % 10 == 0 {
                tickLength = 14
                tickWidth = 1.2 * invScale
            } else if deg % 5 == 0 {
                tickLength = 9
                tickWidth = 0.8 * invScale
            } else {
                tickLength = 5
                tickWidth = 0.5 * invScale
            }

            let outerX = cos(angleRad) * radius
            let outerY = sin(angleRad) * radius
            let innerX = cos(angleRad) * (radius - tickLength)
            let innerY = sin(angleRad) * (radius - tickLength)

            ctx.setLineWidth(tickWidth)
            ctx.move(to: CGPoint(x: outerX, y: outerY))
            ctx.addLine(to: CGPoint(x: innerX, y: innerY))
            ctx.strokePath()
        }

        let font = CTFontCreateWithName("Helvetica Neue" as CFString, 8, nil)
        let textColor = NSColor.labelColor.withAlphaComponent(0.55)

        for deg in stride(from: 0, through: 180, by: 10) {
            let angleRad = .pi + Double(deg) * .pi / 180.0
            let textRadius = radius - 22
            let tx = cos(angleRad) * textRadius
            let ty = sin(angleRad) * textRadius

            let text = "\(deg)°"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font as Any,
                .foregroundColor: textColor
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let line = CTLineCreateWithAttributedString(attrStr)
            let textBounds = CTLineGetBoundsWithOptions(line, [])

            ctx.saveGState()
            ctx.translateBy(x: tx - textBounds.width / 2, y: ty)
            ctx.scaleBy(x: 1, y: -1)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        let crossSize: CGFloat = 8
        let crossColor = NSColor.systemOrange.withAlphaComponent(0.5).cgColor
        ctx.setStrokeColor(crossColor)
        ctx.setLineWidth(1.0 * invScale)
        ctx.move(to: CGPoint(x: -crossSize, y: 0))
        ctx.addLine(to: CGPoint(x: crossSize, y: 0))
        ctx.move(to: CGPoint(x: 0, y: -crossSize))
        ctx.addLine(to: CGPoint(x: 0, y: crossSize))
        ctx.strokePath()

        drawRotationHandle(in: ctx, at: CGPoint(x: radius + 10, y: 0), invScale: invScale,
                           color: NSColor.systemOrange)

        ctx.restoreGState()
    }

    // MARK: - Rotation Handle

    private static func drawRotationHandle(in ctx: CGContext, at point: CGPoint,
                                            invScale: CGFloat, color: NSColor) {
        let handleRadius: CGFloat = 7
        let rect = CGRect(x: point.x - handleRadius, y: point.y - handleRadius,
                          width: handleRadius * 2, height: handleRadius * 2)

        ctx.setFillColor(color.withAlphaComponent(0.15).cgColor)
        ctx.fillEllipse(in: rect)

        ctx.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.5 * invScale)
        ctx.strokeEllipse(in: rect)

        let arrowSize: CGFloat = 4
        ctx.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.2 * invScale)

        ctx.beginPath()
        ctx.addArc(center: point, radius: handleRadius * 0.55,
                   startAngle: -.pi * 0.6, endAngle: .pi * 0.6, clockwise: false)
        ctx.strokePath()

        let tipAngle: Double = .pi * 0.6
        let tipX = point.x + cos(tipAngle) * handleRadius * 0.55
        let tipY = point.y + sin(tipAngle) * handleRadius * 0.55
        ctx.move(to: CGPoint(x: tipX, y: tipY))
        ctx.addLine(to: CGPoint(x: tipX + arrowSize * 0.5, y: tipY - arrowSize))
        ctx.move(to: CGPoint(x: tipX, y: tipY))
        ctx.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY - arrowSize * 0.3))
        ctx.strokePath()
    }
}
