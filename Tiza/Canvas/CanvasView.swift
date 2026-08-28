import AppKit
import CoreGraphics
import QuartzCore
import UniformTypeIdentifiers

final class CanvasView: NSView {
    var camera = Camera()
    var boardData: BoardData?
    var background: BoardBackground = .white
    private var currentBoardId: UUID?
    private var currentBoardIndex: Int = 0

    weak var toolManager: ToolManager?
    weak var document: TizaDocument?
    weak var instrumentManager: InstrumentManager?
    weak var presentationManager: PresentationManager?
    var externalUndoManager: UndoManager?

    var onCameraChanged: ((Camera) -> Void)?

    private var activeTextField: NSTextField?
    private var activeTextView: NSTextView?
    private var activeEquationField: NSTextField?
    private var textEditWorldPosition: WorldPoint?
    private var equationEditWorldPosition: WorldPoint?
    private var lastScreenPosition: CGPoint = .zero
    private var laserDisplayLink: CADisplayLink?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.drawsAsynchronously = true
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let viewSize = bounds.size

        BoardBackgroundRenderer.draw(background, in: ctx, viewSize: viewSize,
                                     camera: camera, appearance: effectiveAppearance)

        if let board = boardData {
            let cache = document?.imageCache ?? [:]
            let selIds = toolManager?.selectedElementIds ?? []
            let delta = (toolManager?.isMoving == true) ? (toolManager?.moveDelta ?? .zero) : .zero
            let offsets = toolManager?.animator.animatingOffsets ?? [:]
            Renderer.drawElements(board.elements, in: ctx, camera: camera,
                                  viewSize: viewSize, imageCache: cache,
                                  selectedIds: selIds, moveDelta: delta,
                                  animatingOffsets: offsets)
        }

        if let animator = toolManager?.animator, !animator.deletingElements.isEmpty {
            let cache = document?.imageCache ?? [:]
            Renderer.drawDeletingElements(animator.deletingElements, in: ctx, camera: camera,
                                           viewSize: viewSize, imageCache: cache)
        }

        if let im = instrumentManager, !im.instruments.isEmpty {
            InstrumentRenderer.drawInstruments(im.instruments, in: ctx,
                                               camera: camera, viewSize: viewSize)
        }

        drawToolOverlays(in: ctx, viewSize: viewSize)
        drawPresentationOverlays(in: ctx, viewSize: viewSize)
    }

    private func drawToolOverlays(in ctx: CGContext, viewSize: CGSize) {
        guard let tm = toolManager else { return }

        if !tm.inProgressPoints.isEmpty {
            Renderer.drawInProgressStroke(
                points: tm.inProgressPoints,
                color: tm.inProgressColor,
                thickness: tm.inProgressThickness,
                style: tm.inProgressStyle,
                in: ctx, camera: camera, viewSize: viewSize
            )
        }

        if let shapeType = tm.inProgressShapeType {
            Renderer.drawInProgressShape(
                type: shapeType,
                origin: tm.inProgressShapeOrigin,
                size: tm.inProgressShapeSize,
                color: tm.inProgressShapeColor,
                thickness: tm.inProgressShapeThickness,
                in: ctx, camera: camera, viewSize: viewSize
            )
        }

        if let rect = tm.dragSelectionRect {
            Renderer.drawDragRect(rect, crossing: tm.dragSelectionCrossing,
                                  in: ctx, camera: camera, viewSize: viewSize)
        }

        if !tm.activeSmartGuides.isEmpty {
            Renderer.drawSmartGuides(tm.activeSmartGuides, in: ctx,
                                      camera: camera, viewSize: viewSize)
        }

        if let source = tm.inProgressConnectorSource, let target = tm.inProgressConnectorTarget {
            Renderer.drawInProgressConnector(source: source, target: target,
                                              color: tm.inProgressConnectorColor,
                                              in: ctx, camera: camera, viewSize: viewSize)
        }

        if !tm.selectedElementIds.isEmpty, let board = boardData {
            if let resizeBounds = tm.resizingBounds {
                Renderer.drawSelectionHandles(resizeBounds, offset: .zero,
                                               in: ctx, camera: camera, viewSize: viewSize)
            } else if let bounds = tm.selectionBounds(in: board) {
                let offset = tm.isMoving ? tm.moveDelta : .zero
                Renderer.drawSelectionHandles(bounds, offset: offset,
                                               in: ctx, camera: camera, viewSize: viewSize)
            }
        }
    }

    // MARK: - Presentation Overlays

    private func drawPresentationOverlays(in ctx: CGContext, viewSize: CGSize) {
        guard let pm = presentationManager else { return }

        if pm.spotlightActive {
            PresentationRenderer.drawSpotlight(
                at: pm.spotlightScreenPosition ?? lastScreenPosition,
                radius: pm.spotlightRadius, in: ctx, viewSize: viewSize
            )
        }

        if pm.hasLaserContent {
            PresentationRenderer.drawLaser(pm, in: ctx, camera: camera, viewSize: viewSize)
        }
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let screenPoint = convert(event.locationInWindow, from: nil)
        lastScreenPosition = screenPoint

        guard let pm = presentationManager else { return }

        if pm.laserActive {
            let world = camera.screenToWorld(screenPoint, viewSize: bounds.size)
            pm.addLaserPoint(world)
            ensureLaserTimer()
        }

        if pm.spotlightActive {
            pm.spotlightScreenPosition = screenPoint
            needsDisplay = true
        }
    }

    private func ensureLaserTimer() {
        guard laserDisplayLink == nil else { return }
        let target = LaserDisplayLinkTarget { [weak self] in
            guard let self else { return }
            self.presentationManager?.updateTrail()
            if self.presentationManager?.hasLaserContent == true {
                self.needsDisplay = true
            } else {
                self.stopLaserTimer()
            }
        }
        let link = self.displayLink(target: target, selector: #selector(LaserDisplayLinkTarget.step))
        link.add(to: .main, forMode: .common)
        laserDisplayLink = link
    }

    private func stopLaserTimer() {
        laserDisplayLink?.invalidate()
        laserDisplayLink = nil
        needsDisplay = true
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        commitTextEditing()
        commitEquationEditing()

        let screenPoint = convert(event.locationInWindow, from: nil)
        lastScreenPosition = screenPoint
        let world = screenToWorld(event)

        if let pm = presentationManager {
            if pm.spotlightActive { pm.spotlightScreenPosition = screenPoint }
            if pm.laserActive {
                pm.addLaserPoint(world)
                ensureLaserTimer()
                needsDisplay = true
                return
            }
        }

        if let im = instrumentManager, im.beginInteraction(at: world) {
            needsDisplay = true
            return
        }

        guard let tm = toolManager, let ctx = makeToolContext() else { return }
        tm.lastEventPressure = Double(event.pressure)
        tm.pointerDown(at: world, context: ctx)

        if let pos = tm.textEditingPosition, activeTextField == nil, activeTextView == nil {
            beginTextEditing(at: pos)
        }

        if let pos = tm.equationEditingPosition, activeEquationField == nil {
            beginEquationEditing(at: pos)
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let screenPoint = convert(event.locationInWindow, from: nil)
        lastScreenPosition = screenPoint
        let world = screenToWorld(event)

        if let pm = presentationManager {
            if pm.spotlightActive { pm.spotlightScreenPosition = screenPoint }
            if pm.laserActive {
                pm.addLaserPoint(world)
                needsDisplay = true
                return
            }
        }

        if let im = instrumentManager, im.isInteracting {
            im.updateInteraction(to: world)
            needsDisplay = true
            return
        }

        guard let ctx = makeToolContext() else { return }
        toolManager?.lastEventPressure = Double(event.pressure)
        toolManager?.pointerDragged(to: world, context: ctx)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let screenPoint = convert(event.locationInWindow, from: nil)
        lastScreenPosition = screenPoint
        let world = screenToWorld(event)

        if let pm = presentationManager {
            if pm.spotlightActive { pm.spotlightScreenPosition = screenPoint }
            if pm.laserActive {
                needsDisplay = true
                return
            }
        }

        if let im = instrumentManager, im.isInteracting {
            im.updateInteraction(to: world)
            im.endInteraction()
            needsDisplay = true
            return
        }

        guard let ctx = makeToolContext() else { return }
        toolManager?.lastEventPressure = Double(event.pressure)
        toolManager?.pointerUp(at: world, context: ctx)
        needsDisplay = true
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: toolManager?.cursor ?? .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        toolManager?.cursor.set()
    }

    // MARK: - Text Editing

    private func beginTextEditing(at worldPoint: WorldPoint) {
        textEditWorldPosition = worldPoint

        let screenPoint = camera.worldToScreen(worldPoint, viewSize: bounds.size)
        let preset = toolManager?.textPreset
        let fontSize: CGFloat = preset?.fontSize ?? 24.0
        let weight: NSFont.Weight = (preset?.isBold == true) ? .bold : .regular

        let scrollView = NSScrollView(frame: NSRect(x: screenPoint.x - 2, y: screenPoint.y - fontSize - 2,
                                                     width: 300, height: fontSize * 3 + 12))
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.font = .systemFont(ofSize: fontSize, weight: weight)
        textView.textColor = toolManager?.currentColor.nsColor ?? .labelColor
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.focusRingType = .none
        textView.isEditable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.size = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = self

        scrollView.documentView = textView
        addSubview(scrollView)
        window?.makeFirstResponder(textView)
        activeTextView = textView
    }

    @objc private func textFieldAction(_ sender: NSTextField) {
        commitTextEditing()
    }

    private func commitTextEditing() {
        if let textView = activeTextView {
            let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let position = textEditWorldPosition
            let preset = toolManager?.textPreset

            textView.enclosingScrollView?.removeFromSuperview()
            activeTextView = nil
            textEditWorldPosition = nil
            toolManager?.textEditingPosition = nil
            toolManager?.textPreset = nil

            guard !text.isEmpty, let position = position, let ctx = makeToolContext() else {
                toolManager?.restorePreviousTool()
                window?.makeFirstResponder(self)
                return
            }

            let fontSize = preset?.fontSize ?? 24.0
            let bold = preset?.isBold ?? false
            let isMultiline = text.contains("\n")

            let textData = TextData(
                position: [position.x, position.y],
                content: text,
                fontSize: fontSize,
                color: toolManager?.currentColor ?? .black,
                bold: bold,
                rotation: 0,
                width: isMultiline ? 300.0 : nil
            )

            let zIndex = boardData?.nextZIndex ?? 0
            let element = Element(type: .text(textData), zIndex: zIndex)
            ctx.addElement(element)

            toolManager?.restorePreviousTool()
            window?.makeFirstResponder(self)
            needsDisplay = true
            return
        }

        guard let field = activeTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = textEditWorldPosition

        field.removeFromSuperview()
        activeTextField = nil
        textEditWorldPosition = nil
        toolManager?.textEditingPosition = nil
        toolManager?.textPreset = nil

        guard !text.isEmpty, let position = position, let ctx = makeToolContext() else {
            toolManager?.restorePreviousTool()
            window?.makeFirstResponder(self)
            return
        }

        let textData = TextData(
            position: [position.x, position.y],
            content: text,
            fontSize: 24.0,
            color: toolManager?.currentColor ?? .black,
            bold: false,
            rotation: 0
        )

        let zIndex = boardData?.nextZIndex ?? 0
        let element = Element(type: .text(textData), zIndex: zIndex)
        ctx.addElement(element)

        toolManager?.restorePreviousTool()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func cancelTextEditing() {
        if let textView = activeTextView {
            textView.enclosingScrollView?.removeFromSuperview()
            activeTextView = nil
        }
        if let field = activeTextField {
            field.removeFromSuperview()
            activeTextField = nil
        }
        textEditWorldPosition = nil
        toolManager?.textEditingPosition = nil
        toolManager?.textPreset = nil
        toolManager?.restorePreviousTool()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: - Equation Editing

    private func beginEquationEditing(at worldPoint: WorldPoint) {
        equationEditWorldPosition = worldPoint
        let screenPoint = camera.worldToScreen(worldPoint, viewSize: bounds.size)

        let field = NSTextField(frame: NSRect(x: screenPoint.x - 2, y: screenPoint.y - 26,
                                              width: 300, height: 28))
        field.font = .systemFont(ofSize: 16)
        field.textColor = .labelColor
        field.placeholderString = "LaTeX: e.g. x^{2} + \\alpha"
        field.isBordered = true
        field.drawsBackground = true
        field.backgroundColor = .controlBackgroundColor
        field.focusRingType = .default
        field.isEditable = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        field.target = self
        field.action = #selector(equationFieldAction(_:))
        field.tag = 999

        addSubview(field)
        window?.makeFirstResponder(field)
        activeEquationField = field
    }

    @objc private func equationFieldAction(_ sender: NSTextField) {
        commitEquationEditing()
    }

    private func commitEquationEditing() {
        guard let field = activeEquationField else { return }
        let latex = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = equationEditWorldPosition

        field.removeFromSuperview()
        activeEquationField = nil
        equationEditWorldPosition = nil
        toolManager?.equationEditingPosition = nil

        guard !latex.isEmpty, let position = position, let ctx = makeToolContext() else {
            toolManager?.restorePreviousTool()
            window?.makeFirstResponder(self)
            return
        }

        let eqData = EquationData(
            position: [position.x, position.y],
            latex: latex,
            fontSize: 24.0,
            color: toolManager?.currentColor ?? .black
        )

        let zIndex = boardData?.nextZIndex ?? 0
        let element = Element(type: .equation(eqData), zIndex: zIndex)
        ctx.addElement(element)

        toolManager?.restorePreviousTool()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: - Paste

    @IBAction func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        guard let image = NSImage(pasteboard: pb) else { return }
        pasteImage(image)
    }

    private func pasteImage(_ image: NSImage, at worldCenter: WorldPoint? = nil) {
        guard let doc = document, let ctx = makeToolContext() else { return }

        let assetId = doc.addImageAsset(image)
        let center = worldCenter ?? camera.screenToWorld(
            CGPoint(x: bounds.midX, y: bounds.midY), viewSize: bounds.size
        )

        var w = image.size.width
        var h = image.size.height
        let maxDim: CGFloat = 600
        if max(w, h) > maxDim {
            let ratio = maxDim / max(w, h)
            w *= ratio
            h *= ratio
        }

        let imageData = ImageData(
            assetId: assetId,
            origin: [center.x - w / 2, center.y - h / 2],
            size: [w, h],
            rotation: 0
        )

        let zIndex = boardData?.nextZIndex ?? 0
        let element = Element(type: .image(imageData), zIndex: zIndex)
        ctx.addElement(element)
        needsDisplay = true
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return imageFromDragging(sender) != nil ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let image = imageFromDragging(sender) else { return false }
        let dropScreen = convert(sender.draggingLocation, from: nil)
        let worldPoint = camera.screenToWorld(dropScreen, viewSize: bounds.size)
        pasteImage(image, at: worldPoint)
        return true
    }

    private func imageFromDragging(_ sender: NSDraggingInfo) -> NSImage? {
        let pb = sender.draggingPasteboard
        if let data = pb.data(forType: .tiff), let image = NSImage(data: data) { return image }
        if let data = pb.data(forType: .png), let image = NSImage(data: data) { return image }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let uti = UTType(filenameExtension: url.pathExtension), uti.conforms(to: .image),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }
        return nil
    }

    // MARK: - Pan (scroll wheel / two-finger scroll)

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            let factor: CGFloat = event.scrollingDeltaY > 0 ? 1.05 : 0.95
            let location = convert(event.locationInWindow, from: nil)
            camera.zoom(by: factor, anchor: location, viewSize: bounds.size)
        } else {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            camera.pan(byScreenDelta: CGPoint(x: dx, y: dy))
        }

        onCameraChanged?(camera)
        needsDisplay = true
    }

    // MARK: - Pinch to zoom

    override func magnify(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let factor = 1.0 + event.magnification
        camera.zoom(by: factor, anchor: location, viewSize: bounds.size)

        onCameraChanged?(camera)
        needsDisplay = true
    }

    // MARK: - Smart zoom (double-tap on trackpad)

    override func smartMagnify(with event: NSEvent) {
        let targetScale: CGFloat = camera.scale < 1.5 ? 2.0 : 1.0
        let location = convert(event.locationInWindow, from: nil)
        let factor = targetScale / camera.scale
        camera.zoom(by: factor, anchor: location, viewSize: bounds.size)

        onCameraChanged?(camera)
        needsDisplay = true
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }

    // MARK: - Helpers

    private func screenToWorld(_ event: NSEvent) -> WorldPoint {
        let screenPoint = convert(event.locationInWindow, from: nil)
        return camera.screenToWorld(screenPoint, viewSize: bounds.size)
    }

    private func makeToolContext() -> ToolContext? {
        guard let doc = document, let tm = toolManager else { return nil }
        return ToolContext(document: doc, undoManager: externalUndoManager,
                          toolManager: tm, instrumentManager: instrumentManager)
    }

    // MARK: - Update

    func updateBoard(_ board: BoardData?, background: BoardBackground, camera newCamera: Camera, boardId: UUID? = nil, boardIndex: Int = 0) {
        if toolManager?.textEditingPosition == nil && activeTextField != nil {
            commitTextEditing()
        }

        let backgroundChanged = self.background != background
        let boardChanged = boardId != nil && currentBoardId != nil && boardId != currentBoardId

        if boardChanged, let layer {
            let transition = CATransition()
            transition.type = .push
            transition.duration = 0.25
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            transition.subtype = boardIndex >= currentBoardIndex ? .fromRight : .fromLeft
            layer.add(transition, forKey: "boardSlide")
        } else if backgroundChanged, let layer {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(transition, forKey: "backgroundTransition")
        }

        self.boardData = board
        self.background = background
        self.camera = newCamera
        self.currentBoardId = boardId
        self.currentBoardIndex = boardIndex
        toolManager?.currentBackground = background
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    func setCamera(_ newCamera: Camera) {
        self.camera = newCamera
        needsDisplay = true
    }
}

// MARK: - NSTextFieldDelegate

extension CanvasView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if control.tag == 999 {
                activeEquationField?.removeFromSuperview()
                activeEquationField = nil
                equationEditWorldPosition = nil
                toolManager?.equationEditingPosition = nil
                toolManager?.restorePreviousTool()
                window?.makeFirstResponder(self)
            } else {
                cancelTextEditing()
            }
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if control.tag == 999 {
                commitEquationEditing()
            } else {
                commitTextEditing()
            }
            return true
        }
        return false
    }
}

// MARK: - NSTextViewDelegate

extension CanvasView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEditing()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSEvent.modifierFlags.contains(.shift) {
                commitTextEditing()
                return true
            }
        }
        return false
    }
}

private final class LaserDisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func step(_ link: CADisplayLink) { callback() }
}
