import AppKit
import Combine

final class InstrumentManager: ObservableObject {
    @Published var instruments: [InstrumentState] = []

    var activeInteraction: InstrumentInteraction?

    struct InstrumentInteraction {
        let instrumentId: UUID
        let zone: InstrumentHitZone
        let startPoint: CGPoint
        let startCenter: CGPoint
        let startAngle: Double
    }

    var isInteracting: Bool { activeInteraction != nil }

    func addRuler(at center: CGPoint) {
        let ruler = InstrumentState(kind: .ruler, center: center)
        instruments.append(ruler)
    }

    func addProtractor(at center: CGPoint) {
        let protractor = InstrumentState(kind: .protractor, center: center)
        instruments.append(protractor)
    }

    func removeInstrument(id: UUID) {
        instruments.removeAll { $0.id == id }
    }

    func toggleRuler(at center: CGPoint) {
        if let idx = instruments.firstIndex(where: { $0.kind == .ruler }) {
            instruments.remove(at: idx)
        } else {
            addRuler(at: center)
        }
    }

    func toggleProtractor(at center: CGPoint) {
        if let idx = instruments.firstIndex(where: { $0.kind == .protractor }) {
            instruments.remove(at: idx)
        } else {
            addProtractor(at: center)
        }
    }

    var hasRuler: Bool { instruments.contains { $0.kind == .ruler } }
    var hasProtractor: Bool { instruments.contains { $0.kind == .protractor } }

    // MARK: - Interaction

    func beginInteraction(at point: CGPoint) -> Bool {
        guard let (instrument, zone) = InstrumentHitTesting.hitTest(
            point: point, instruments: instruments
        ) else { return false }

        activeInteraction = InstrumentInteraction(
            instrumentId: instrument.id,
            zone: zone,
            startPoint: point,
            startCenter: instrument.center,
            startAngle: instrument.angle
        )
        return true
    }

    func updateInteraction(to point: CGPoint) {
        guard let interaction = activeInteraction,
              let idx = instruments.firstIndex(where: { $0.id == interaction.instrumentId })
        else { return }

        switch interaction.zone {
        case .body:
            let delta = point - interaction.startPoint
            instruments[idx].center = interaction.startCenter + delta

        case .rotationHandle:
            let current = atan2(
                point.y - instruments[idx].center.y,
                point.x - instruments[idx].center.x
            )
            let start = atan2(
                interaction.startPoint.y - interaction.startCenter.y,
                interaction.startPoint.x - interaction.startCenter.x
            )
            instruments[idx].angle = interaction.startAngle + (current - start)
        }
    }

    func endInteraction() {
        activeInteraction = nil
    }

    // MARK: - Constraint

    func constrain(_ point: CGPoint, threshold: CGFloat = 15) -> CGPoint? {
        var bestPoint: CGPoint?
        var bestDistance: CGFloat = threshold

        for instrument in instruments {
            if let constrained = constrainToInstrument(point, instrument: instrument) {
                let dist = point.distance(to: constrained)
                if dist < bestDistance {
                    bestDistance = dist
                    bestPoint = constrained
                }
            }
        }

        return bestPoint
    }

    private func constrainToInstrument(_ point: CGPoint, instrument: InstrumentState) -> CGPoint? {
        switch instrument.kind {
        case .ruler:
            return constrainToRuler(point, instrument: instrument)
        case .protractor:
            return constrainToProtractorArc(point, instrument: instrument)
        }
    }

    private func constrainToRuler(_ point: CGPoint, instrument: InstrumentState) -> CGPoint? {
        let (edgeA, edgeB) = instrument.rulerEdgeEndpoints()

        let ab = edgeB - edgeA
        let ap = point - edgeA
        let lengthSq = ab.x * ab.x + ab.y * ab.y
        guard lengthSq > 0 else { return nil }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSq))

        return CGPoint(x: edgeA.x + t * ab.x, y: edgeA.y + t * ab.y)
    }

    private func constrainToProtractorArc(_ point: CGPoint, instrument: InstrumentState) -> CGPoint? {
        let dx = point.x - instrument.center.x
        let dy = point.y - instrument.center.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 1 else { return nil }

        let radius = InstrumentState.protractorRadius

        let localAngle = atan2(dy, dx) - instrument.angle
        let normalized = localAngle < -.pi ? localAngle + 2 * .pi :
                         (localAngle > .pi ? localAngle - 2 * .pi : localAngle)

        guard normalized >= -.pi && normalized <= 0 else { return nil }

        return CGPoint(
            x: instrument.center.x + (dx / dist) * radius,
            y: instrument.center.y + (dy / dist) * radius
        )
    }
}
