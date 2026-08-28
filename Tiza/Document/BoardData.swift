import Foundation
import CoreGraphics

struct BoardData: Codable, Equatable {
    var id: UUID
    var elements: [Element]

    init(id: UUID = UUID(), elements: [Element] = []) {
        self.id = id
        self.elements = elements
    }

    var nextZIndex: Int {
        (elements.map(\.zIndex).max() ?? -1) + 1
    }

    var boundingBox: WorldRect? {
        guard !elements.isEmpty else { return nil }
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for element in elements {
            let bounds = HitTesting.elementBounds(element)
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        return WorldRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
