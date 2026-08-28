import XCTest
@testable import TeachBoard

final class DocumentSerializationTests: XCTestCase {
    func testDefaultDocumentModelEncoding() throws {
        let model = DocumentModel.makeDefault()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(model)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DocumentModel.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.boards.count, 1)
        XCTAssertEqual(decoded.activeBoardIndex, 0)
    }

    func testBoardDataRoundTrip() throws {
        let board = BoardData(id: UUID(), elements: [])
        let encoder = JSONEncoder()
        let data = try encoder.encode(board)
        let decoded = try JSONDecoder().decode(BoardData.self, from: data)

        XCTAssertEqual(board.id, decoded.id)
        XCTAssertEqual(decoded.elements.count, 0)
    }

    func testCodableColorRoundTrip() throws {
        let color = CodableColor.red
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)

        XCTAssertEqual(color, decoded)
    }

    func testCameraStateRoundTrip() throws {
        let state = CameraState(x: 100, y: 200, scale: 2.5)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CameraState.self, from: data)

        XCTAssertEqual(state, decoded)
    }
}
