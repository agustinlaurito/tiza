import AppKit
import CoreGraphics

final class CanvasView: NSView {
    var camera = Camera()
    var boardData: BoardData?
    var background: BoardBackground = .white

    var onCameraChanged: ((Camera) -> Void)?

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
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let viewSize = bounds.size

        BoardBackgroundRenderer.draw(background, in: ctx, viewSize: viewSize,
                                     camera: camera, appearance: effectiveAppearance)

        if let board = boardData {
            Renderer.drawElements(board.elements, in: ctx, camera: camera, viewSize: viewSize)
        }
    }

    // MARK: - Pan (scroll wheel / two-finger scroll)

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            // Option+scroll = zoom
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

    // MARK: - Keyboard zoom

    override func keyDown(with event: NSEvent) {
        // Single-key tool shortcuts will be handled by ToolManager (Phase 2)
        super.keyDown(with: event)
    }

    // MARK: - Update

    func updateBoard(_ board: BoardData?, background: BoardBackground, camera newCamera: Camera) {
        self.boardData = board
        self.background = background
        self.camera = newCamera
        needsDisplay = true
    }

    func setCamera(_ newCamera: Camera) {
        self.camera = newCamera
        needsDisplay = true
    }
}
