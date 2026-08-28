import SwiftUI
import UniformTypeIdentifiers

@main
struct TeachBoardApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { TeachBoardDocument() }) { config in
            MainWindowContent(document: config.document)
        }
        .commands {
            exportCommands
            boardCommands
            viewCommands
            toolCommands
            instrumentCommands
            presentationCommands
        }
    }

    private var exportCommands: some Commands {
        CommandGroup(replacing: .importExport) {
            Button("Export as PNG\u{2026}") {
                NotificationCenter.default.post(name: .exportPNG, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Export as PDF\u{2026}") {
                NotificationCenter.default.post(name: .exportPDF, object: nil)
            }
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

            Divider()

            Button("Clear Board") {
                NotificationCenter.default.post(name: .clearBoard, object: nil)
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

    private var toolCommands: some Commands {
        CommandMenu("Tools") {
            ForEach(ToolType.drawingTools) { tool in
                Button(tool.displayName) {
                    NotificationCenter.default.post(name: .switchTool,
                                                     object: tool.rawValue)
                }
                .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
            }
        }
    }

    private var instrumentCommands: some Commands {
        CommandMenu("Instruments") {
            Button("Toggle Ruler") {
                NotificationCenter.default.post(name: .toggleRuler, object: nil)
            }
            .keyboardShortcut("u", modifiers: .command)

            Button("Toggle Protractor") {
                NotificationCenter.default.post(name: .toggleProtractor, object: nil)
            }
            .keyboardShortcut("j", modifiers: .command)
        }
    }

    private var presentationCommands: some Commands {
        CommandMenu("Presentation") {
            Button("Laser Pointer (Hold Space)") {}
                .disabled(true)

            Divider()

            Button("Toggle Spotlight") {
                NotificationCenter.default.post(name: .toggleSpotlight, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
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
    static let switchTool = Notification.Name("TeachBoard.switchTool")
    static let clearBoard = Notification.Name("TeachBoard.clearBoard")
    static let toggleRuler = Notification.Name("TeachBoard.toggleRuler")
    static let toggleProtractor = Notification.Name("TeachBoard.toggleProtractor")
    static let toggleSpotlight = Notification.Name("TeachBoard.toggleSpotlight")
    static let exportPNG = Notification.Name("TeachBoard.exportPNG")
    static let exportPDF = Notification.Name("TeachBoard.exportPDF")
}
