import SwiftUI

struct MainWindowContent: View {
    @ObservedObject var document: TeachBoardDocument
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasRepresentable(document: document)
                .ignoresSafeArea()

            BoardNavigator(document: document)
                .padding(.bottom, 12)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if handleKeyEvent(event) {
                    return nil
                }
                return event
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Board navigation
        if event.keyCode == 121 { // Page Down (fn+↓)
            withAnimation(.easeInOut(duration: 0.15)) {
                document.nextBoard()
            }
            return true
        }
        if event.keyCode == 116 { // Page Up (fn+↑)
            withAnimation(.easeInOut(duration: 0.15)) {
                document.previousBoard()
            }
            return true
        }

        // ⇧⌘N — New Board
        if flags == [.shift, .command], event.charactersIgnoringModifiers == "n" {
            withAnimation(.easeInOut(duration: 0.15)) {
                document.addBoard(undoManager: undoManager)
            }
            return true
        }

        // ⇧⌘D — Duplicate Board
        if flags == [.shift, .command], event.charactersIgnoringModifiers == "d" {
            withAnimation(.easeInOut(duration: 0.15)) {
                document.duplicateBoard(at: document.model.activeBoardIndex,
                                         undoManager: undoManager)
            }
            return true
        }

        return false
    }
}
