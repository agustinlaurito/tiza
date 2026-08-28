import XCTest
@testable import Tiza

final class PresentationManagerTests: XCTestCase {
    func testLaserActivation() {
        let pm = PresentationManager()
        XCTAssertFalse(pm.laserActive)
        pm.activateLaser()
        XCTAssertTrue(pm.laserActive)
    }

    func testLaserDeactivation() {
        let pm = PresentationManager()
        pm.activateLaser()
        pm.addLaserPoint(CGPoint(x: 10, y: 10))
        pm.deactivateLaser()

        XCTAssertFalse(pm.laserActive)
        XCTAssertNil(pm.laserPosition)
    }

    func testAddLaserPoint() {
        let pm = PresentationManager()
        pm.activateLaser()
        pm.addLaserPoint(CGPoint(x: 50, y: 60))

        XCTAssertEqual(pm.laserPosition, CGPoint(x: 50, y: 60))
        XCTAssertEqual(pm.laserTrail.count, 1)
        XCTAssertEqual(pm.laserTrail[0].position, CGPoint(x: 50, y: 60))
    }

    func testHasLaserContent() {
        let pm = PresentationManager()
        XCTAssertFalse(pm.hasLaserContent)

        pm.activateLaser()
        XCTAssertTrue(pm.hasLaserContent)

        pm.deactivateLaser()
        XCTAssertFalse(pm.hasLaserContent)
    }

    func testHasLaserContentWithTrail() {
        let pm = PresentationManager()
        pm.activateLaser()
        pm.addLaserPoint(CGPoint(x: 10, y: 10))
        pm.deactivateLaser()

        XCTAssertTrue(pm.hasLaserContent)
    }

    func testSpotlightToggle() {
        let pm = PresentationManager()
        XCTAssertFalse(pm.spotlightActive)
        pm.spotlightActive = true
        XCTAssertTrue(pm.spotlightActive)
    }

    func testSpotlightDefaults() {
        let pm = PresentationManager()
        XCTAssertEqual(pm.spotlightRadius, 120)
        XCTAssertNil(pm.spotlightScreenPosition)
    }

    func testTrailDuration() {
        let pm = PresentationManager()
        XCTAssertEqual(pm.trailDuration, 1.2)
    }
}
