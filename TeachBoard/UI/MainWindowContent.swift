import SwiftUI

struct MainWindowContent: View {
    @ObservedObject var document: TeachBoardDocument
    @StateObject private var toolManager = ToolManager()
    @StateObject private var instrumentManager = InstrumentManager()
    @StateObject private var presentationManager = PresentationManager()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ZStack {
            CanvasRepresentable(document: document, toolManager: toolManager,
                                instrumentManager: instrumentManager,
                                presentationManager: presentationManager,
                                undoManager: undoManager)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    Spacer()

                    VStack(spacing: 8) {
                        ToolbarView(toolManager: toolManager)
                        BoardNavigator(document: document)
                    }

                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    ZoomIndicator(document: document)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear { installKeyMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: .addBoard)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                document.addBoard(undoManager: undoManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .duplicateBoard)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                document.duplicateBoard(at: document.model.activeBoardIndex,
                                         undoManager: undoManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteBoard)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                document.removeBoard(at: document.model.activeBoardIndex,
                                      undoManager: undoManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextBoard)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { document.nextBoard() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousBoard)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { document.previousBoard() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            zoomCanvas(by: 1.25)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            zoomCanvas(by: 0.8)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomFit)) { _ in
            zoomToFit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTool)) { notification in
            if let rawValue = notification.object as? String,
               let toolType = ToolType(rawValue: rawValue) {
                toolManager.switchTool(toolType)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearBoard)) { _ in
            document.clearBoard(undoManager: undoManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRuler)) { _ in
            let center = document.activeBoardReference?.camera.camera.center ?? .zero
            instrumentManager.toggleRuler(at: center)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleProtractor)) { _ in
            let center = document.activeBoardReference?.camera.camera.center ?? .zero
            instrumentManager.toggleProtractor(at: center)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSpotlight)) { _ in
            presentationManager.spotlightActive.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPNG)) { _ in
            exportPNG()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in
            exportPDF()
        }
    }

    // MARK: - Zoom

    private func zoomCanvas(by factor: CGFloat) {
        guard document.model.activeBoardIndex < document.model.boards.count else { return }
        var camera = document.model.boards[document.model.activeBoardIndex].camera.camera
        let viewCenter = CGPoint(x: 500, y: 400)
        camera.zoom(by: factor, anchor: viewCenter, viewSize: CGSize(width: 1000, height: 800))
        document.updateCamera(camera)
    }

    private func zoomToFit() {
        guard let board = document.activeBoardData else { return }
        guard !board.elements.isEmpty else {
            let camera = Camera()
            document.updateCamera(camera)
            return
        }

        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for element in board.elements {
            let bounds = HitTesting.elementBounds(element)
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        let contentWidth = maxX - minX
        let contentHeight = maxY - minY
        guard contentWidth > 0, contentHeight > 0 else { return }

        let padding: CGFloat = 60
        let viewWidth: CGFloat = 1000 - padding * 2
        let viewHeight: CGFloat = 800 - padding * 2
        let scale = min(viewWidth / contentWidth, viewHeight / contentHeight, 5.0)

        var camera = Camera()
        camera.center = CGPoint(x: minX + contentWidth / 2, y: minY + contentHeight / 2)
        camera.scale = max(scale, 0.1)
        document.updateCamera(camera)
    }

    // MARK: - Export

    private func exportPNG() {
        guard let board = document.activeBoardData,
              let ref = document.activeBoardReference else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = (ref.name ?? "Board") + ".png"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let appearance = NSApp.keyWindow?.effectiveAppearance

            if let data = BoardExporter.exportAsPNG(
                board: board, background: ref.background,
                imageCache: document.imageCache, appearance: appearance
            ) {
                try? data.write(to: url)
            }
        }
    }

    private func exportPDF() {
        guard let board = document.activeBoardData,
              let ref = document.activeBoardReference else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (ref.name ?? "Board") + ".pdf"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let appearance = NSApp.keyWindow?.effectiveAppearance

            let data = BoardExporter.exportAsPDF(
                board: board, background: ref.background,
                imageCache: document.imageCache, appearance: appearance
            )
            try? data.write(to: url)
        }
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handleKeyEvent(event) { return nil }
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            if handleKeyUpEvent(event) { return nil }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 49 && !event.isARepeat && flags.isEmpty {
            let responder = NSApp.keyWindow?.firstResponder
            if !(responder is NSTextView) {
                presentationManager.activateLaser()
                return true
            }
        }

        if flags.isEmpty, let chars = event.charactersIgnoringModifiers, chars.count == 1 {
            let char = chars.first!
            if let toolType = ToolType.allCases.first(where: { $0.shortcutKey == char }) {
                if ToolType.drawingTools.contains(toolType) {
                    toolManager.switchTool(toolType)
                    return true
                }
            }

            if char == "\u{7F}" || char == "\u{F728}" {
                let ctx = ToolContext(document: document, undoManager: undoManager,
                                      toolManager: toolManager,
                                      instrumentManager: instrumentManager)
                toolManager.deleteSelection(context: ctx)
                return true
            }
        }

        if event.keyCode == 53 {
            toolManager.cancel()
            return true
        }

        if event.keyCode == 121 {
            withAnimation(.easeInOut(duration: 0.15)) { document.nextBoard() }
            return true
        }
        if event.keyCode == 116 {
            withAnimation(.easeInOut(duration: 0.15)) { document.previousBoard() }
            return true
        }

        if flags == [.shift, .command], event.charactersIgnoringModifiers == "n" {
            withAnimation(.easeInOut(duration: 0.15)) {
                document.addBoard(undoManager: undoManager)
            }
            return true
        }

        if flags == [.shift, .command], event.charactersIgnoringModifiers == "d" {
            withAnimation(.easeInOut(duration: 0.15)) {
                document.duplicateBoard(at: document.model.activeBoardIndex,
                                         undoManager: undoManager)
            }
            return true
        }

        return false
    }

    private func handleKeyUpEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == 49 {
            presentationManager.deactivateLaser()
            return true
        }
        return false
    }
}
