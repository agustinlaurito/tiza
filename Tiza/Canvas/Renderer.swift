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

    static func drawDeletingElements(_ elements: [CanvasAnimator.DeletingElement],
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
        case .connector(let data):
            drawConnector(data, in: ctx, scale: scale)
        case .table(let data):
            drawTable(data, in: ctx, scale: scale)
        case .equation(let data):
            drawEquation(data, in: ctx, scale: scale)
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

    static func drawInProgressConnector(source: CGPoint, target: CGPoint, color: CodableColor,
                                         in context: CGContext, camera: Camera, viewSize: CGSize) {
        let transform = camera.affineTransform(for: viewSize)
        context.saveGState()
        context.concatenate(transform)

        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(2.0 / camera.scale)
        context.setLineCap(.round)
        context.setLineDash(phase: 0, lengths: [6 / camera.scale, 3 / camera.scale])

        context.beginPath()
        context.move(to: source)
        context.addLine(to: target)
        context.strokePath()

        drawArrowhead(at: target, from: source, in: context,
                      size: 8 / camera.scale)

        context.restoreGState()
    }
}
