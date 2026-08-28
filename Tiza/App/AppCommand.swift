import SwiftUI

enum AppCommand {
    case addBoard
    case duplicateBoard
    case deleteBoard
    case nextBoard
    case previousBoard
    case clearBoard
    case zoomIn
    case zoomOut
    case zoomFit
    case switchTool(ToolType)
    case toggleRuler
    case toggleProtractor
    case toggleSpotlight
    case exportPNG
    case exportPDF
}

struct AppCommandHandlerKey: FocusedValueKey {
    typealias Value = (AppCommand) -> Void
}

extension FocusedValues {
    var commandHandler: ((AppCommand) -> Void)? {
        get { self[AppCommandHandlerKey.self] }
        set { self[AppCommandHandlerKey.self] = newValue }
    }
}
