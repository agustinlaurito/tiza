import SwiftUI

struct CanvasRepresentable: NSViewRepresentable {
    @ObservedObject var document: TeachBoardDocument

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView(frame: .zero)
        view.onCameraChanged = { [weak document] newCamera in
            document?.updateCamera(newCamera)
        }
        updateView(view)
        return view
    }

    func updateNSView(_ view: CanvasView, context: Context) {
        updateView(view)
    }

    private func updateView(_ view: CanvasView) {
        guard let ref = document.activeBoardReference else { return }
        let boardData = document.boardDataMap[ref.id]
        view.updateBoard(boardData, background: ref.background, camera: ref.camera.camera)
    }
}
