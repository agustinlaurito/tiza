import Foundation

struct DocumentModel: Codable, Equatable {
    var schemaVersion: Int = 1
    var activeBoardIndex: Int = 0
    var boards: [BoardReference] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    static func makeDefault() -> DocumentModel {
        let board = BoardReference()
        return DocumentModel(boards: [board])
    }
}

enum BoardBackground: String, Codable, CaseIterable, Equatable {
    case white
    case dark
    case grid
    case dottedGrid
    case lined

    var displayName: String {
        switch self {
        case .white: "White"
        case .dark: "Dark"
        case .grid: "Grid"
        case .dottedGrid: "Dotted Grid"
        case .lined: "Lined"
        }
    }
}

struct BoardReference: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String?
    var camera: CameraState
    var background: BoardBackground

    init(id: UUID = UUID(), name: String? = nil,
         camera: CameraState = CameraState(), background: BoardBackground = .white) {
        self.id = id
        self.name = name
        self.camera = camera
        self.background = background
    }

    var displayName: String {
        name ?? "Board"
    }
}
