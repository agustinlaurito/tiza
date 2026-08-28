import SwiftUI

struct CanvasRepresentable: NSViewRepresentable {
    @ObservedObject var document: TeachBoardDocument
    @ObservedObject var toolManager: ToolManager
    @ObservedObject var instrumentManager: InstrumentManager
    @ObservedObject var presentationManager: PresentationManager
    var undoManager: UndoManager?

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView(frame: .zero)
        view.document = document
        view.toolManager = toolManager
        view.instrumentManager = instrumentManager
        view.presentationManager = presentationManager
        view.externalUndoManager = undoManager
        view.onCameraChanged = { [weak document] newCamera in
            document?.updateCamera(newCamera)
        }
        updateView(view)
        return view
    }

    func updateNSView(_ view: CanvasView, context: Context) {
        view.document = document
        view.toolManager = toolManager
        view.instrumentManager = instrumentManager
        view.presentationManager = presentationManager
        view.externalUndoManager = undoManager
        updateView(view)
    }

    private func updateView(_ view: CanvasView) {
        guard let ref = document.activeBoardReference else { return }
        let boardData = document.boardDataMap[ref.id]
        view.updateBoard(boardData, background: ref.background, camera: ref.camera.camera)
    }
}
