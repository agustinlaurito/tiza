import XCTest
@testable import TeachBoard

final class ExportTests: XCTestCase {
    func testExportEmptyBoardAsPNG() {
        let board = BoardData()
        let data = BoardExporter.exportAsPNG(
            board: board, background: .white,
            imageCache: [:], appearance: nil
        )
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 0)
    }

    func testExportBoardWithElementAsPNG() {
        var board = BoardData()
        board.elements.append(Element(type: .shape(ShapeData(
            shapeType: .rectangle, origin: [10, 10], size: [200, 100], rotation: 0,
            strokeColor: .black, fillColor: nil, strokeWidth: 2
        )), zIndex: 0))

        let data = BoardExporter.exportAsPNG(
            board: board, background: .white,
            imageCache: [:], appearance: nil
        )
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 100)
    }

    func testExportEmptyBoardAsPDF() {
        let board = BoardData()
        let data = BoardExporter.exportAsPDF(
            board: board, background: .white,
            imageCache: [:], appearance: nil
        )
        XCTAssertGreaterThan(data.count, 0)
    }

    func testExportBoardWithElementAsPDF() {
        var board = BoardData()
        board.elements.append(Element(type: .stroke(StrokeData(
            points: [[0, 0], [100, 100], [200, 50]],
            color: .red, thickness: 4, style: .pen
        )), zIndex: 0))

        let data = BoardExporter.exportAsPDF(
            board: board, background: .grid,
            imageCache: [:], appearance: nil
        )
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPNGDataIsValidPNG() {
        let board = BoardData()
        guard let data = BoardExporter.exportAsPNG(
            board: board, background: .white,
            imageCache: [:], appearance: nil
        ) else {
            XCTFail("Expected PNG data")
            return
        }

        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let bytes = [UInt8](data.prefix(4))
        XCTAssertEqual(bytes, header)
    }

    func testPDFDataIsValidPDF() {
        let board = BoardData()
        let data = BoardExporter.exportAsPDF(
            board: board, background: .white,
            imageCache: [:], appearance: nil
        )
        let prefix = String(data: data.prefix(5), encoding: .ascii)
        XCTAssertEqual(prefix, "%PDF-")
    }
}
