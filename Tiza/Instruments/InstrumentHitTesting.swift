import CoreGraphics

enum InstrumentHitTesting {
    static let threshold: CGFloat = 8

    static func hitTest(point: CGPoint, instruments: [InstrumentState])
        -> (instrument: InstrumentState, zone: InstrumentHitZone)?
    {
        for instrument in instruments.reversed() {
            if let zone = hitTestSingle(point: point, instrument: instrument) {
                return (instrument, zone)
            }
        }
        return nil
    }

    private static func hitTestSingle(point: CGPoint, instrument: InstrumentState) -> InstrumentHitZone? {
        switch instrument.kind {
        case .ruler:
            return hitTestRuler(point: point, instrument: instrument)
        case .protractor:
            return hitTestProtractor(point: point, instrument: instrument)
        }
    }

    // MARK: - Ruler

    private static func hitTestRuler(point: CGPoint, instrument: InstrumentState) -> InstrumentHitZone? {
        let local = toLocal(point, center: instrument.center, angle: instrument.angle)
        let halfLength = InstrumentState.rulerLength / 2
        let halfWidth = InstrumentState.rulerWidth / 2

        let handleRadius: CGFloat = 14
        let handleCenter = CGPoint(x: halfLength + 4, y: 0)
        if local.distance(to: handleCenter) < handleRadius {
            return .rotationHandle
        }

        let bodyRect = CGRect(
            x: -halfLength - threshold,
            y: -halfWidth - threshold,
            width: InstrumentState.rulerLength + threshold * 2,
            height: InstrumentState.rulerWidth + threshold * 2
        )
        if bodyRect.contains(local) {
            return .body
        }

        return nil
    }

    // MARK: - Protractor

    private static func hitTestProtractor(point: CGPoint, instrument: InstrumentState) -> InstrumentHitZone? {
        let local = toLocal(point, center: instrument.center, angle: instrument.angle)
        let radius = InstrumentState.protractorRadius

        let handleCenter = CGPoint(x: radius + 10, y: 0)
        if local.distance(to: handleCenter) < 14 {
            return .rotationHandle
        }

        let dist = local.distance(to: .zero)

        if dist <= radius + threshold {
            let angle = atan2(local.y, local.x)
            if angle >= -.pi && angle <= 0 || dist <= 20 {
                return .body
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static func toLocal(_ point: CGPoint, center: CGPoint, angle: Double) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = cos(-angle)
        let sinA = sin(-angle)
        return CGPoint(x: dx * cosA - dy * sinA, y: dx * sinA + dy * cosA)
    }
}
