import SwiftUI
import UniformTypeIdentifiers

@main
struct TeachBoardApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { TeachBoardDocument() }) { config in
            MainWindowContent(document: config.document)
        }
        .commands {
            boardCommands
            viewCommands
        }
    }

    private var boardCommands: some Commands {
        CommandMenu("Board") {
            Button("New Board") {
                NotificationCenter.default.post(name: .addBoard, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])

            Button("Duplicate Board") {
                NotificationCenter.default.post(name: .duplicateBoard, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.shift, .command])

            Divider()

            Button("Next Board") {
                NotificationCenter.default.post(name: .nextBoard, object: nil)
            }
            .keyboardShortcut(.pageDown, modifiers: [])

            Button("Previous Board") {
                NotificationCenter.default.post(name: .previousBoard, object: nil)
            }
            .keyboardShortcut(.pageUp, modifiers: [])

            Divider()

            Button("Delete Board") {
                NotificationCenter.default.post(name: .deleteBoard, object: nil)
            }
        }
    }

    private var viewCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Zoom In") {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Fit Content") {
                NotificationCenter.default.post(name: .zoomFit, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let addBoard = Notification.Name("TeachBoard.addBoard")
    static let duplicateBoard = Notification.Name("TeachBoard.duplicateBoard")
    static let deleteBoard = Notification.Name("TeachBoard.deleteBoard")
    static let nextBoard = Notification.Name("TeachBoard.nextBoard")
    static let previousBoard = Notification.Name("TeachBoard.previousBoard")
    static let zoomIn = Notification.Name("TeachBoard.zoomIn")
    static let zoomOut = Notification.Name("TeachBoard.zoomOut")
    static let zoomFit = Notification.Name("TeachBoard.zoomFit")
}
