import XCTest
@testable import Tiza

final class InstrumentTests: XCTestCase {
    var manager: InstrumentManager!

    override func setUp() {
        super.setUp()
        manager = InstrumentManager()
    }

    // MARK: - Add / Remove

    func testAddRuler() {
        manager.addRuler(at: CGPoint(x: 100, y: 200))
        XCTAssertEqual(manager.instruments.count, 1)
        XCTAssertEqual(manager.instruments[0].kind, .ruler)
        XCTAssertEqual(manager.instruments[0].center, CGPoint(x: 100, y: 200))
    }

    func testAddProtractor() {
        manager.addProtractor(at: CGPoint(x: 50, y: 50))
        XCTAssertEqual(manager.instruments.count, 1)
        XCTAssertEqual(manager.instruments[0].kind, .protractor)
    }

    func testRemoveInstrument() {
        manager.addRuler(at: .zero)
        let id = manager.instruments[0].id
        manager.removeInstrument(id: id)
        XCTAssertTrue(manager.instruments.isEmpty)
    }

    func testToggleRuler() {
        manager.toggleRuler(at: .zero)
        XCTAssertTrue(manager.hasRuler)
        manager.toggleRuler(at: .zero)
        XCTAssertFalse(manager.hasRuler)
    }

    func testToggleProtractor() {
        manager.toggleProtractor(at: .zero)
        XCTAssertTrue(manager.hasProtractor)
        manager.toggleProtractor(at: .zero)
        XCTAssertFalse(manager.hasProtractor)
    }

    func testHasRulerAndProtractor() {
        XCTAssertFalse(manager.hasRuler)
        XCTAssertFalse(manager.hasProtractor)
        manager.addRuler(at: .zero)
        manager.addProtractor(at: .zero)
        XCTAssertTrue(manager.hasRuler)
        XCTAssertTrue(manager.hasProtractor)
    }

    // MARK: - Ruler Edge Endpoints

    func testRulerEdgeEndpointsAtZeroAngle() {
        let ruler = InstrumentState(kind: .ruler, center: CGPoint(x: 0, y: 0), angle: 0)
        let (a, b) = ruler.rulerEdgeEndpoints()

        let halfLength = InstrumentState.rulerLength / 2
        let halfWidth = InstrumentState.rulerWidth / 2

        XCTAssertEqual(a.x, -halfLength, accuracy: 0.001)
        XCTAssertEqual(a.y, halfWidth, accuracy: 0.001)
        XCTAssertEqual(b.x, halfLength, accuracy: 0.001)
        XCTAssertEqual(b.y, halfWidth, accuracy: 0.001)
    }

    // MARK: - Constraint: Ruler

    func testConstrainToRulerSnaps() {
        manager.addRuler(at: CGPoint(x: 0, y: 0))

        let halfWidth = InstrumentState.rulerWidth / 2
        let nearEdge = CGPoint(x: 0, y: halfWidth + 5)
        let result = manager.constrain(nearEdge)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.y, halfWidth, accuracy: 0.5)
    }

    func testConstrainFarPointReturnsNil() {
        manager.addRuler(at: CGPoint(x: 0, y: 0))
        let farPoint = CGPoint(x: 0, y: 500)
        let result = manager.constrain(farPoint, threshold: 15)
        XCTAssertNil(result)
    }

    // MARK: - Constraint: Protractor

    func testConstrainToProtractorArc() {
        manager.addProtractor(at: CGPoint(x: 0, y: 0))
        let radius = InstrumentState.protractorRadius

        let nearArc = CGPoint(x: radius - 5, y: -10)
        let result = manager.constrain(nearArc)

        XCTAssertNotNil(result)
        let dist = sqrt(result!.x * result!.x + result!.y * result!.y)
        XCTAssertEqual(dist, radius, accuracy: 0.5)
    }

    func testConstrainProtractorBelowArcReturnsNil() {
        manager.addProtractor(at: CGPoint(x: 0, y: 0))
        let radius = InstrumentState.protractorRadius

        let below = CGPoint(x: radius - 5, y: 50)
        let result = manager.constrain(below, threshold: 15)
        XCTAssertNil(result)
    }

    // MARK: - Interaction

    func testIsInteractingDefault() {
        XCTAssertFalse(manager.isInteracting)
    }

    func testEndInteractionClearsState() {
        manager.addRuler(at: .zero)
        let center = manager.instruments[0].center
        _ = manager.beginInteraction(at: center)
        XCTAssertTrue(manager.isInteracting)
        manager.endInteraction()
        XCTAssertFalse(manager.isInteracting)
    }

    // MARK: - Hit Testing

    func testHitTestRulerBody() {
        let ruler = InstrumentState(kind: .ruler, center: CGPoint(x: 100, y: 100), angle: 0)
        let result = InstrumentHitTesting.hitTest(point: CGPoint(x: 100, y: 100), instruments: [ruler])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.zone, .body)
    }

    func testHitTestMiss() {
        let ruler = InstrumentState(kind: .ruler, center: CGPoint(x: 100, y: 100), angle: 0)
        let result = InstrumentHitTesting.hitTest(point: CGPoint(x: 1000, y: 1000), instruments: [ruler])
        XCTAssertNil(result)
    }

    func testHitTestProtractorBody() {
        let protractor = InstrumentState(kind: .protractor, center: CGPoint(x: 200, y: 200), angle: 0)
        let result = InstrumentHitTesting.hitTest(point: CGPoint(x: 200, y: 200), instruments: [protractor])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.zone, .body)
    }

    func testHitTestReturnsTopInstrument() {
        let bottom = InstrumentState(kind: .ruler, center: CGPoint(x: 100, y: 100), angle: 0)
        let top = InstrumentState(kind: .protractor, center: CGPoint(x: 100, y: 100), angle: 0)
        let result = InstrumentHitTesting.hitTest(point: CGPoint(x: 100, y: 100), instruments: [bottom, top])
        XCTAssertEqual(result?.instrument.kind, .protractor)
    }
}
