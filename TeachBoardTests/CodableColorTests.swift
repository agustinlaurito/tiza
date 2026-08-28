import XCTest
@testable import TeachBoard

final class CodableColorTests: XCTestCase {
    func testPredefinedColors() {
        XCTAssertEqual(CodableColor.black.r, 0)
        XCTAssertEqual(CodableColor.black.g, 0)
        XCTAssertEqual(CodableColor.black.b, 0)
        XCTAssertEqual(CodableColor.white.r, 1)
        XCTAssertEqual(CodableColor.white.g, 1)
        XCTAssertEqual(CodableColor.white.b, 1)
    }

    func testEquality() {
        let a = CodableColor(r: 0.5, g: 0.5, b: 0.5)
        let b = CodableColor(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(CodableColor.red, CodableColor.blue)
    }

    func testCodableRoundTrip() throws {
        let color = CodableColor(r: 0.25, g: 0.5, b: 0.75, a: 0.9)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        XCTAssertEqual(decoded.r, 0.25, accuracy: 0.0001)
        XCTAssertEqual(decoded.g, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.b, 0.75, accuracy: 0.0001)
        XCTAssertEqual(decoded.a, 0.9, accuracy: 0.0001)
    }

    func testCGColorConversion() {
        let color = CodableColor(r: 1, g: 0, b: 0)
        let cg = color.cgColor
        XCTAssertNotNil(cg)
        let components = cg.components!
        XCTAssertEqual(components[0], 1.0, accuracy: 0.001)
        XCTAssertEqual(components[1], 0.0, accuracy: 0.001)
        XCTAssertEqual(components[2], 0.0, accuracy: 0.001)
    }

    func testPaletteContainsExpectedColors() {
        XCTAssertEqual(CodableColor.palette.count, 7)
        XCTAssertTrue(CodableColor.palette.contains(.black))
        XCTAssertTrue(CodableColor.palette.contains(.white))
        XCTAssertTrue(CodableColor.palette.contains(.red))
    }

    func testHashable() {
        let set: Set<CodableColor> = [.black, .black, .red]
        XCTAssertEqual(set.count, 2)
    }

    func testDefaultAlpha() {
        let color = CodableColor(r: 0, g: 0, b: 0)
        XCTAssertEqual(color.a, 1.0)
    }
}
