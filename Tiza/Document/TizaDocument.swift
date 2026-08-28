import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let tiza = UTType(exportedAs: "com.tiza.document", conformingTo: .package)
}

final class TizaDocument: ReferenceFileDocument, @unchecked Sendable {
    typealias Snapshot = DocumentSnapshot

    static var readableContentTypes: [UTType] { [.tiza] }
    static var writableContentTypes: [UTType] { [.tiza] }

    @Published var model: DocumentModel
    @Published var boardDataMap: [UUID: BoardData]
    var imageCache: [String: NSImage] = [:]

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

        if let assetFiles = wrapper["assets"]?.fileWrappers {
            for (filename, fileWrapper) in assetFiles {
                if let data = fileWrapper.regularFileContents,
                   let image = NSImage(data: data) {
                    let id = (filename as NSString).deletingPathExtension
                    imageCache[id] = image
                }
            }
        }
    }

    // MARK: - Snapshot & Save

    struct DocumentSnapshot {
        let model: DocumentModel
        let boardDataMap: [UUID: BoardData]
        let imageCache: [String: NSImage]
    }

    func snapshot(contentType: UTType) throws -> DocumentSnapshot {
        var snapshotModel = model
        snapshotModel.modifiedAt = Date()
        return DocumentSnapshot(model: snapshotModel, boardDataMap: boardDataMap,
                                imageCache: imageCache)
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

        for (id, image) in snapshot.imageCache {
            if let rep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: rep),
               let png = bitmap.representation(using: .png, properties: [:]) {
                let assetWrapper = FileWrapper(regularFileWithContents: png)
                assetWrapper.preferredFilename = id + ".png"
                assetsDirectory.addFileWrapper(assetWrapper)
            }
        }

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

    // MARK: - Element Operations

    func addElement(_ element: Element, undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference else { return }
        boardDataMap[ref.id, default: BoardData(id: ref.id)].elements.append(element)

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.removeElement(id: element.id, undoManager: undoManager)
        }
    }

    func removeElement(id: UUID, undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference,
              var board = boardDataMap[ref.id],
              let index = board.elements.firstIndex(where: { $0.id == id }) else { return }

        let removed = board.elements.remove(at: index)
        boardDataMap[ref.id] = board

        undoManager?.registerUndo(withTarget: self) { doc in
            guard var b = doc.boardDataMap[ref.id] else { return }
            let insertAt = min(index, b.elements.count)
            b.elements.insert(removed, at: insertAt)
            doc.boardDataMap[ref.id] = b

            undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.removeElement(id: removed.id, undoManager: undoManager)
            }
        }
    }

    func moveElements(ids: Set<UUID>, delta: CGPoint, undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference,
              var board = boardDataMap[ref.id] else { return }

        for i in board.elements.indices where ids.contains(board.elements[i].id) {
            board.elements[i] = Self.offsetElement(board.elements[i], by: delta)
        }
        boardDataMap[ref.id] = board

        let reverse = CGPoint(x: -delta.x, y: -delta.y)
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.moveElements(ids: ids, delta: reverse, undoManager: undoManager)
        }
    }

    private static func offsetElement(_ element: Element, by delta: CGPoint) -> Element {
        var e = element
        switch e.type {
        case .stroke(var data):
            data.points = data.points.map { [$0[0] + delta.x, $0[1] + delta.y] }
            e.type = .stroke(data)

        case .shape(var data):
            data.origin = [data.origin[0] + delta.x, data.origin[1] + delta.y]
            e.type = .shape(data)

        case .text(var data):
            data.position = [data.position[0] + delta.x, data.position[1] + delta.y]
            e.type = .text(data)

        case .image(var data):
            data.origin = [data.origin[0] + delta.x, data.origin[1] + delta.y]
            e.type = .image(data)
        }
        return e
    }

    func updateElement(id: UUID, undoManager: UndoManager? = nil, transform: (inout Element) -> Void) {
        guard let ref = activeBoardReference,
              var board = boardDataMap[ref.id],
              let index = board.elements.firstIndex(where: { $0.id == id }) else { return }

        let old = board.elements[index]
        transform(&board.elements[index])
        let updated = board.elements[index]
        boardDataMap[ref.id] = board

        undoManager?.registerUndo(withTarget: self) { doc in
            guard var b = doc.boardDataMap[ref.id],
                  let i = b.elements.firstIndex(where: { $0.id == id }) else { return }
            b.elements[i] = old
            doc.boardDataMap[ref.id] = b
            undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.updateElement(id: id, undoManager: undoManager) { $0 = updated }
            }
        }
    }

    func duplicateElement(id: UUID, undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference,
              let board = boardDataMap[ref.id],
              let element = board.elements.first(where: { $0.id == id }) else { return }

        var copy = element
        copy.id = UUID()
        copy = Self.offsetElement(copy, by: CGPoint(x: 20, y: 20))
        addElement(copy, undoManager: undoManager)
    }

    func scaleElement(id: UUID, factor: CGFloat, undoManager: UndoManager? = nil) {
        updateElement(id: id, undoManager: undoManager) { element in
            switch element.type {
            case .stroke(var data):
                let bounds = HitTesting.elementBounds(element)
                let cx = bounds.midX, cy = bounds.midY
                data.points = data.points.map { p in
                    [cx + (p[0] - cx) * factor, cy + (p[1] - cy) * factor]
                }
                data.thickness *= factor
                element.type = .stroke(data)

            case .shape(var data):
                let cx = data.origin[0] + data.size[0] / 2
                let cy = data.origin[1] + data.size[1] / 2
                let newW = data.size[0] * factor
                let newH = data.size[1] * factor
                data.origin = [cx - newW / 2, cy - newH / 2]
                data.size = [newW, newH]
                data.strokeWidth *= factor
                element.type = .shape(data)

            case .text(var data):
                data.fontSize = max(data.fontSize * factor, 8)
                element.type = .text(data)

            case .image(var data):
                let cx = data.origin[0] + data.size[0] / 2
                let cy = data.origin[1] + data.size[1] / 2
                let newW = data.size[0] * factor
                let newH = data.size[1] * factor
                data.origin = [cx - newW / 2, cy - newH / 2]
                data.size = [newW, newH]
                element.type = .image(data)
            }
        }
    }

    func resizeElement(id: UUID, newBounds: CGRect, undoManager: UndoManager? = nil) {
        updateElement(id: id, undoManager: undoManager) { element in
            let oldBounds = HitTesting.elementBounds(element)
            guard oldBounds.width > 0, oldBounds.height > 0 else { return }
            let sx = newBounds.width / oldBounds.width
            let sy = newBounds.height / oldBounds.height

            switch element.type {
            case .stroke(var data):
                data.points = data.points.map { p in
                    let nx = newBounds.minX + (p[0] - oldBounds.minX) * sx
                    let ny = newBounds.minY + (p[1] - oldBounds.minY) * sy
                    return [nx, ny]
                }
                element.type = .stroke(data)

            case .shape(var data):
                data.origin = [newBounds.origin.x, newBounds.origin.y]
                data.size = [newBounds.width, newBounds.height]
                element.type = .shape(data)

            case .text(var data):
                data.fontSize = max(data.fontSize * max(sx, sy), 8)
                data.position = [newBounds.minX,
                                 newBounds.minY + data.fontSize * 1.4]
                element.type = .text(data)

            case .image(var data):
                data.origin = [newBounds.origin.x, newBounds.origin.y]
                data.size = [newBounds.width, newBounds.height]
                element.type = .image(data)
            }
        }
    }

    // MARK: - Alignment

    func alignElements(ids: Set<UUID>, alignment: AlignmentMode, undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference,
              var board = boardDataMap[ref.id] else { return }

        let selected = board.elements.filter { ids.contains($0.id) }
        guard selected.count >= 2 else { return }

        let idBounds: [(UUID, CGRect)] = selected.map { ($0.id, HitTesting.elementBounds($0)) }
        let groupMinX = idBounds.map(\.1.minX).min()!
        let groupMaxX = idBounds.map(\.1.maxX).max()!
        let groupMinY = idBounds.map(\.1.minY).min()!
        let groupMaxY = idBounds.map(\.1.maxY).max()!
        let groupMidX = (groupMinX + groupMaxX) / 2
        let groupMidY = (groupMinY + groupMaxY) / 2

        let oldElements = board.elements

        for i in board.elements.indices where ids.contains(board.elements[i].id) {
            let elementId = board.elements[i].id
            let bounds = HitTesting.elementBounds(board.elements[i])
            var dx: CGFloat = 0
            var dy: CGFloat = 0

            switch alignment {
            case .left:    dx = groupMinX - bounds.minX
            case .centerH: dx = groupMidX - bounds.midX
            case .right:   dx = groupMaxX - bounds.maxX
            case .top:     dy = groupMinY - bounds.minY
            case .centerV: dy = groupMidY - bounds.midY
            case .bottom:  dy = groupMaxY - bounds.maxY
            case .distributeH:
                let sorted = idBounds.sorted { $0.1.midX < $1.1.midX }
                guard let pos = sorted.firstIndex(where: { $0.0 == elementId }) else { continue }
                if sorted.count < 2 { continue }
                let totalWidth = idBounds.reduce(0) { $0 + $1.1.width }
                let gap = (groupMaxX - groupMinX - totalWidth) / CGFloat(sorted.count - 1)
                var x = groupMinX
                for j in 0..<pos {
                    x += sorted[j].1.width + gap
                }
                dx = x - bounds.minX
            case .distributeV:
                let sorted = idBounds.sorted { $0.1.midY < $1.1.midY }
                guard let pos = sorted.firstIndex(where: { $0.0 == elementId }) else { continue }
                if sorted.count < 2 { continue }
                let totalHeight = idBounds.reduce(0) { $0 + $1.1.height }
                let gap = (groupMaxY - groupMinY - totalHeight) / CGFloat(sorted.count - 1)
                var y = groupMinY
                for j in 0..<pos {
                    y += sorted[j].1.height + gap
                }
                dy = y - bounds.minY
            }

            if dx != 0 || dy != 0 {
                board.elements[i] = Self.offsetElement(board.elements[i], by: CGPoint(x: dx, y: dy))
            }
        }

        boardDataMap[ref.id] = board

        undoManager?.registerUndo(withTarget: self) { doc in
            guard var b = doc.boardDataMap[ref.id] else { return }
            b.elements = oldElements
            doc.boardDataMap[ref.id] = b
            undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.alignElements(ids: ids, alignment: alignment, undoManager: undoManager)
            }
        }
    }

    func clearBoard(undoManager: UndoManager? = nil) {
        guard let ref = activeBoardReference,
              var board = boardDataMap[ref.id], !board.elements.isEmpty else { return }

        let saved = board.elements
        board.elements = []
        boardDataMap[ref.id] = board

        undoManager?.registerUndo(withTarget: self) { doc in
            guard var b = doc.boardDataMap[ref.id] else { return }
            b.elements = saved
            doc.boardDataMap[ref.id] = b
            undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.clearBoard(undoManager: undoManager)
            }
        }
    }

    // MARK: - Image Assets

    func addImageAsset(_ image: NSImage) -> String {
        let id = UUID().uuidString
        imageCache[id] = image
        return id
    }
}
