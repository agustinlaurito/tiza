import SwiftUI

struct MainWindowContent: View {
    @ObservedObject var document: TizaDocument
    @StateObject private var toolManager = ToolManager()
    @StateObject private var instrumentManager = InstrumentManager()
    @StateObject private var presentationManager = PresentationManager()
    @Environment(\.undoManager) private var undoManager

    @State private var showWelcome = true
    @State private var toolbarVisible = true
    @State private var isHoveringToolbar = false
    @State private var hideTask: Task<Void, Never>?
    @State private var showContextMenu = false

    private let autoHideDelay: UInt64 = 3_000_000_000

    private var isDocumentEmpty: Bool {
        document.boardDataMap.values.allSatisfy { $0.elements.isEmpty }
    }

    var body: some View {
        mainContent
            .frame(minWidth: 800, minHeight: 600)
            .onAppear {
                installKeyMonitor()
                if !isDocumentEmpty {
                    showWelcome = false
                    scheduleToolbarHide()
                }
            }
            .modifier(NotificationHandlers(
                document: document,
                toolManager: toolManager,
                instrumentManager: instrumentManager,
                presentationManager: presentationManager,
                undoManager: undoManager,
                exportPNG: exportPNG,
                exportPDF: exportPDF,
                zoomCanvas: zoomCanvas,
                zoomToFit: zoomToFit
            ))
            .onChange(of: toolManager.selectedElementIds) {
                if !toolManager.selectedElementIds.isEmpty {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showContextMenu = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showContextMenu = false
                    }
                }
            }
    }

    private var mainContent: some View {
        ZStack {
            CanvasRepresentable(document: document, toolManager: toolManager,
                                instrumentManager: instrumentManager,
                                presentationManager: presentationManager,
                                undoManager: undoManager)
                .ignoresSafeArea()

            if showContextMenu, !showWelcome {
                contextMenuOverlay
            }

            if !showWelcome {
                floatingToolbar
            }

            if showWelcome {
                WelcomeOverlay(
                    onNewWhiteboard: { dismissWelcome() },
                    onOpenExisting: {
                        dismissWelcome()
                        DispatchQueue.main.async {
                            NSApp.sendAction(
                                #selector(NSDocumentController.openDocument(_:)),
                                to: nil, from: nil
                            )
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    private var floatingToolbar: some View {
        VStack {
            Spacer()

            GlassEffectContainer {
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
            }
            .padding(.bottom, 12)
            .opacity(toolbarVisible ? 1.0 : 0)
            .offset(y: toolbarVisible ? 0 : 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onHover { hovering in
            isHoveringToolbar = hovering
            if hovering {
                showToolbar()
            } else {
                scheduleToolbarHide()
            }
        }
    }

    private func dismissWelcome() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showWelcome = false
        }
        scheduleToolbarHide()
    }

    // MARK: - Context Menu

    private var contextMenuOverlay: some View {
        GeometryReader { geo in
            let pos = contextMenuPosition(viewSize: geo.size)
            ElementContextMenu(
                document: document,
                toolManager: toolManager,
                undoManager: undoManager,
                position: pos,
                isPresented: $showContextMenu
            )
        }
        .allowsHitTesting(true)
    }

    private func contextMenuPosition(viewSize: CGSize) -> CGPoint {
        guard let board = document.activeBoardData,
              let ref = document.activeBoardReference,
              let bounds = toolManager.selectionBounds(in: board) else {
            return CGPoint(x: viewSize.width / 2, y: 60)
        }

        let camera = ref.camera.camera
        let delta = toolManager.isMoving ? toolManager.moveDelta : .zero
        let topCenter = WorldPoint(x: bounds.midX + delta.x, y: bounds.minY + delta.y)
        return camera.worldToScreen(topCenter, viewSize: viewSize)
    }

    // MARK: - Toolbar Auto-Hide

    private func showToolbar() {
        hideTask?.cancel()
        if !toolbarVisible {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                toolbarVisible = true
            }
        }
    }

    private func scheduleToolbarHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: autoHideDelay)
            guard !Task.isCancelled, !isHoveringToolbar else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                toolbarVisible = false
            }
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
            document.updateCamera(Camera())
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
        if showWelcome { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isEditing = NSApp.keyWindow?.firstResponder is NSTextView

        if isEditing { return false }

        if event.keyCode == 49 && !event.isARepeat && flags.isEmpty {
            presentationManager.activateLaser()
            return true
        }

        if flags.isEmpty, let chars = event.charactersIgnoringModifiers, chars.count == 1 {
            let char = chars.first!
            if let toolType = ToolType.allCases.first(where: { $0.shortcutKey == char }) {
                if ToolType.drawingTools.contains(toolType) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        toolManager.switchTool(toolType)
                    }
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

        if flags == .command, event.charactersIgnoringModifiers == "g" {
            let ids = toolManager.selectedElementIds
            if ids.count >= 2 {
                document.groupElements(ids: ids, undoManager: undoManager)
            }
            return true
        }

        if flags == [.shift, .command], event.charactersIgnoringModifiers == "g" {
            let ids = toolManager.selectedElementIds
            if !ids.isEmpty {
                document.ungroupElements(ids: ids, undoManager: undoManager)
            }
            return true
        }

        if flags == .command, event.charactersIgnoringModifiers == "l" {
            let ids = toolManager.selectedElementIds
            if !ids.isEmpty {
                document.toggleLock(ids: ids, undoManager: undoManager)
            }
            return true
        }

        if flags == .command, event.charactersIgnoringModifiers == "c" {
            let ids = toolManager.selectedElementIds
            if !ids.isEmpty {
                toolManager.clipboard = document.copyElements(ids: ids)
            }
            return true
        }

        if flags == .command, event.charactersIgnoringModifiers == "v" {
            if !toolManager.clipboard.isEmpty {
                let newIds = document.pasteElements(toolManager.clipboard, undoManager: undoManager)
                toolManager.selectedElementIds = newIds
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

// MARK: - Notification Handlers

private struct NotificationHandlers: ViewModifier {
    let document: TizaDocument
    let toolManager: ToolManager
    let instrumentManager: InstrumentManager
    let presentationManager: PresentationManager
    let undoManager: UndoManager?
    let exportPNG: () -> Void
    let exportPDF: () -> Void
    let zoomCanvas: (CGFloat) -> Void
    let zoomToFit: () -> Void

    func body(content: Content) -> some View {
        content
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
                zoomCanvas(1.25)
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
                zoomCanvas(0.8)
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomFit)) { _ in
                zoomToFit()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchTool)) { notification in
                if let rawValue = notification.object as? String,
                   let toolType = ToolType(rawValue: rawValue) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        toolManager.switchTool(toolType)
                    }
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
}
