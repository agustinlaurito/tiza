import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let teachboard = UTType(exportedAs: "com.teachboard.document", conformingTo: .package)
}

final class TeachBoardDocument: ReferenceFileDocument, @unchecked Sendable {
    typealias Snapshot = DocumentSnapshot

    static var readableContentTypes: [UTType] { [.teachboard] }
    static var writableContentTypes: [UTType] { [.teachboard] }

    @Published var model: DocumentModel
    @Published var boardDataMap: [UUID: BoardData]

    var activeBoardReference: BoardReference? {
        guard model.activeBoardIndex >= 0, model.activeBoardIndex < model.boards.count else {
            return nil
        }
        return model.boards[model.activeBoardIndex]
    }

    var activeBoardData: BoardData? {
        guard let ref = activeBoardReference else { return nil }
        return boardDataMap[ref.id]
    }

    // MARK: - Init

    init() {
        let model = DocumentModel.makeDefault()
        self.model = model
        self.boardDataMap = [:]
        for board in model.boards {
            boardDataMap[board.id] = BoardData(id: board.id)
        }
    }

    required init(configuration: ReadConfiguration) throws {
        guard let wrapper = configuration.file.fileWrappers else {
            throw SchemaError.corruptedDocument("Not a valid document package.")
        }

        guard let documentFile = wrapper["document.json"],
              let documentData = documentFile.regularFileContents else {
            throw SchemaError.corruptedDocument("Missing document.json")
        }

        let migratedData = try SchemaVersion.migrate(documentData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.model = try decoder.decode(DocumentModel.self, from: migratedData)

        let boardsWrapper = wrapper["boards"]?.fileWrappers
        self.boardDataMap = [:]

        for boardRef in model.boards {
            let filename = boardRef.id.uuidString + ".json"
            if let boardFile = boardsWrapper?[filename],
               let boardFileData = boardFile.regularFileContents {
                let board = try decoder.decode(BoardData.self, from: boardFileData)
                boardDataMap[boardRef.id] = board
            } else {
                boardDataMap[boardRef.id] = BoardData(id: boardRef.id)
            }
        }
    }

    // MARK: - Snapshot & Save

    struct DocumentSnapshot {
        let model: DocumentModel
        let boardDataMap: [UUID: BoardData]
    }

    func snapshot(contentType: UTType) throws -> DocumentSnapshot {
        var snapshotModel = model
        snapshotModel.modifiedAt = Date()
        return DocumentSnapshot(model: snapshotModel, boardDataMap: boardDataMap)
    }

    func fileWrapper(snapshot: DocumentSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let documentData = try encoder.encode(snapshot.model)
        let documentFileWrapper = FileWrapper(regularFileWithContents: documentData)
        documentFileWrapper.preferredFilename = "document.json"

        let boardsDirectory = FileWrapper(directoryWithFileWrappers: [:])
        boardsDirectory.preferredFilename = "boards"

        for (id, boardData) in snapshot.boardDataMap {
            let boardFileData = try encoder.encode(boardData)
            let boardFileWrapper = FileWrapper(regularFileWithContents: boardFileData)
            boardFileWrapper.preferredFilename = id.uuidString + ".json"
            boardsDirectory.addFileWrapper(boardFileWrapper)
        }

        let assetsDirectory = FileWrapper(directoryWithFileWrappers: [:])
        assetsDirectory.preferredFilename = "assets"

        let root = FileWrapper(directoryWithFileWrappers: [
            "document.json": documentFileWrapper,
            "boards": boardsDirectory,
            "assets": assetsDirectory
        ])

        return root
    }

    // MARK: - Board Operations

    func addBoard(background: BoardBackground = .white, undoManager: UndoManager? = nil) {
        let ref = BoardReference(background: background)
        let data = BoardData(id: ref.id)

        let insertIndex = model.activeBoardIndex + 1

        model.boards.insert(ref, at: insertIndex)
        boardDataMap[ref.id] = data
        model.activeBoardIndex = insertIndex

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.removeBoard(at: insertIndex, undoManager: undoManager)
        }
    }

    func removeBoard(at index: Int, undoManager: UndoManager? = nil) {
        guard model.boards.count > 1, index < model.boards.count else { return }

        let removedRef = model.boards[index]
        let removedData = boardDataMap[removedRef.id]

        model.boards.remove(at: index)
        boardDataMap.removeValue(forKey: removedRef.id)

        if model.activeBoardIndex >= model.boards.count {
            model.activeBoardIndex = model.boards.count - 1
        }

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.model.boards.insert(removedRef, at: index)
            if let data = removedData {
                doc.boardDataMap[removedRef.id] = data
            }
            doc.model.activeBoardIndex = index
            undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.removeBoard(at: index, undoManager: undoManager)
            }
        }
    }

    func duplicateBoard(at index: Int, undoManager: UndoManager? = nil) {
        guard index < model.boards.count else { return }

        let source = model.boards[index]
        var newRef = BoardReference(
            name: source.name.map { $0 + " (copy)" },
            camera: source.camera,
            background: source.background
        )
        let newId = newRef.id

        let sourceData = boardDataMap[source.id] ?? BoardData(id: source.id)
        var newData = sourceData
        newData.id = newId
        // Deep copy elements with new UUIDs
        newData.elements = sourceData.elements.map { element in
            var copy = element
            copy.id = UUID()
            return copy
        }

        let insertIndex = index + 1
        model.boards.insert(newRef, at: insertIndex)
        boardDataMap[newId] = newData
        model.activeBoardIndex = insertIndex

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.removeBoard(at: insertIndex, undoManager: undoManager)
        }
    }

    func switchToBoard(at index: Int) {
        guard index >= 0, index < model.boards.count else { return }
        model.activeBoardIndex = index
    }

    func nextBoard() {
        let next = model.activeBoardIndex + 1
        if next < model.boards.count {
            model.activeBoardIndex = next
        }
    }

    func previousBoard() {
        let prev = model.activeBoardIndex - 1
        if prev >= 0 {
            model.activeBoardIndex = prev
        }
    }

    func updateCamera(_ camera: Camera) {
        guard model.activeBoardIndex < model.boards.count else { return }
        model.boards[model.activeBoardIndex].camera = CameraState(from: camera)
    }

    func reorderBoards(from source: IndexSet, to destination: Int) {
        model.boards.move(fromOffsets: source, toOffset: destination)
    }
}
