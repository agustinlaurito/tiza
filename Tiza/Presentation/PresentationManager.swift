import AppKit
import CoreGraphics

final class PresentationManager: ObservableObject {
    @Published var spotlightActive = false
    var spotlightRadius: CGFloat = 120
    var spotlightScreenPosition: CGPoint?

    var laserActive = false
    var laserPosition: CGPoint?
    var laserTrail: [(position: CGPoint, time: TimeInterval)] = []
    let trailDuration: TimeInterval = 1.2

    func activateLaser() {
        laserActive = true
    }

    func deactivateLaser() {
        laserActive = false
        laserPosition = nil
    }

    func addLaserPoint(_ worldPoint: CGPoint) {
        laserTrail.append((worldPoint, CACurrentMediaTime()))
        laserPosition = worldPoint
    }

    func updateTrail() {
        let now = CACurrentMediaTime()
        laserTrail.removeAll { now - $0.time > trailDuration }
    }

    var hasLaserContent: Bool {
        laserActive || !laserTrail.isEmpty
    }
}
