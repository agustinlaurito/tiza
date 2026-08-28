import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        UserDefaults.standard.set(false, forKey: "NSShowAppCentricOpenPanelInsteadOfUntitledFile")
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
}

@main
struct TizaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.commandHandler) private var commandHandler

    var body: some Scene {
        DocumentGroup(newDocument: { TizaDocument() }) { config in
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
                commandHandler?(.exportPNG)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Export as PDF\u{2026}") {
                commandHandler?(.exportPDF)
            }
        }
    }

    private var boardCommands: some Commands {
        CommandMenu("Board") {
            Button("New Board") {
                commandHandler?(.addBoard)
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])

            Button("Duplicate Board") {
                commandHandler?(.duplicateBoard)
            }
            .keyboardShortcut("d", modifiers: [.shift, .command])

            Divider()

            Button("Next Board") {
                commandHandler?(.nextBoard)
            }
            .keyboardShortcut(.pageDown, modifiers: [])

            Button("Previous Board") {
                commandHandler?(.previousBoard)
            }
            .keyboardShortcut(.pageUp, modifiers: [])

            Divider()

            Button("Delete Board") {
                commandHandler?(.deleteBoard)
            }

            Divider()

            Button("Clear Board") {
                commandHandler?(.clearBoard)
            }
        }
    }

    private var viewCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Zoom In") {
                commandHandler?(.zoomIn)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                commandHandler?(.zoomOut)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Fit Content") {
                commandHandler?(.zoomFit)
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }

    private var toolCommands: some Commands {
        CommandMenu("Tools") {
            ForEach(ToolType.drawingTools) { tool in
                Button(tool.displayName) {
                    commandHandler?(.switchTool(tool))
                }
                .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
            }
        }
    }

    private var instrumentCommands: some Commands {
        CommandMenu("Instruments") {
            Button("Toggle Ruler") {
                commandHandler?(.toggleRuler)
            }
            .keyboardShortcut("u", modifiers: .command)

            Button("Toggle Protractor") {
                commandHandler?(.toggleProtractor)
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
                commandHandler?(.toggleSpotlight)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
