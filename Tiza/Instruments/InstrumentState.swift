import CoreGraphics
import Foundation

enum InstrumentKind: String, CaseIterable, Identifiable {
    case ruler
    case protractor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ruler: "Ruler"
        case .protractor: "Protractor"
        }
    }

    var systemImage: String {
        switch self {
        case .ruler: "ruler"
        case .protractor: "angle"
        }
    }
}

struct InstrumentState: Identifiable, Equatable {
    let id: UUID
    let kind: InstrumentKind
    var center: CGPoint
    var angle: Double

    static let rulerLength: CGFloat = 800
    static let rulerWidth: CGFloat = 56
    static let protractorRadius: CGFloat = 200

    init(kind: InstrumentKind, center: CGPoint = .zero, angle: Double = 0) {
        self.id = UUID()
        self.kind = kind
        self.center = center
        self.angle = angle
    }

    func rulerEdgeEndpoints() -> (a: CGPoint, b: CGPoint) {
        let halfLength = Self.rulerLength / 2
        let halfWidth = Self.rulerWidth / 2
        let cosA = cos(angle)
        let sinA = sin(angle)

        let a = CGPoint(
            x: center.x + (-halfLength) * cosA - halfWidth * sinA,
            y: center.y + (-halfLength) * sinA + halfWidth * cosA
        )
        let b = CGPoint(
            x: center.x + halfLength * cosA - halfWidth * sinA,
            y: center.y + halfLength * sinA + halfWidth * cosA
        )
        return (a, b)
    }
}

enum InstrumentHitZone {
    case body
    case rotationHandle
}
