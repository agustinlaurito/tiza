import XCTest
@testable import Tiza

final class CameraTests: XCTestCase {
    let viewSize = CGSize(width: 1000, height: 800)

    func testIdentityTransform() {
        let camera = Camera(center: .zero, scale: 1.0)
        let screenPoint = camera.worldToScreen(.zero, viewSize: viewSize)
        XCTAssertEqual(screenPoint.x, 500, accuracy: 0.001)
        XCTAssertEqual(screenPoint.y, 400, accuracy: 0.001)
    }

    func testWorldToScreenRoundTrip() {
        let camera = Camera(center: CGPoint(x: 100, y: 200), scale: 2.0)
        let worldPoint = CGPoint(x: 150, y: 250)
        let screen = camera.worldToScreen(worldPoint, viewSize: viewSize)
        let back = camera.screenToWorld(screen, viewSize: viewSize)
        XCTAssertEqual(back.x, worldPoint.x, accuracy: 0.001)
        XCTAssertEqual(back.y, worldPoint.y, accuracy: 0.001)
    }

    func testZoomPreservesAnchor() {
        var camera = Camera(center: .zero, scale: 1.0)
        let anchor = CGPoint(x: 300, y: 200)

        let worldBefore = camera.screenToWorld(anchor, viewSize: viewSize)
        camera.zoom(by: 2.0, anchor: anchor, viewSize: viewSize)
        let worldAfter = camera.screenToWorld(anchor, viewSize: viewSize)

        XCTAssertEqual(worldBefore.x, worldAfter.x, accuracy: 0.01)
        XCTAssertEqual(worldBefore.y, worldAfter.y, accuracy: 0.01)
    }

    func testZoomClamps() {
        var camera = Camera(center: .zero, scale: 1.0)
        let center = CGPoint(x: 500, y: 400)

        camera.zoom(by: 100, anchor: center, viewSize: viewSize)
        XCTAssertLessThanOrEqual(camera.scale, Camera.maxScale)

        camera.zoom(by: 0.001, anchor: center, viewSize: viewSize)
        XCTAssertGreaterThanOrEqual(camera.scale, Camera.minScale)
    }

    func testPan() {
        var camera = Camera(center: .zero, scale: 1.0)
        camera.pan(byScreenDelta: CGPoint(x: 100, y: 50))

        XCTAssertEqual(camera.center.x, -100, accuracy: 0.001)
        XCTAssertEqual(camera.center.y, -50, accuracy: 0.001)
    }

    func testPanWithZoom() {
        var camera = Camera(center: .zero, scale: 2.0)
        camera.pan(byScreenDelta: CGPoint(x: 100, y: 50))

        XCTAssertEqual(camera.center.x, -50, accuracy: 0.001)
        XCTAssertEqual(camera.center.y, -25, accuracy: 0.001)
    }

    func testVisibleWorldRect() {
        let camera = Camera(center: .zero, scale: 1.0)
        let rect = camera.visibleWorldRect(viewSize: viewSize)

        XCTAssertEqual(rect.width, 1000, accuracy: 0.001)
        XCTAssertEqual(rect.height, 800, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 0, accuracy: 0.001)
    }

    func testVisibleWorldRectZoomed() {
        let camera = Camera(center: .zero, scale: 2.0)
        let rect = camera.visibleWorldRect(viewSize: viewSize)

        XCTAssertEqual(rect.width, 500, accuracy: 0.001)
        XCTAssertEqual(rect.height, 400, accuracy: 0.001)
    }

    func testCameraStateConversion() {
        let camera = Camera(center: CGPoint(x: 42, y: 99), scale: 3.0)
        let state = CameraState(from: camera)
        let restored = state.camera

        XCTAssertEqual(restored.center.x, camera.center.x, accuracy: 0.001)
        XCTAssertEqual(restored.center.y, camera.center.y, accuracy: 0.001)
        XCTAssertEqual(restored.scale, camera.scale, accuracy: 0.001)
    }
}
