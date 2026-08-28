import Foundation

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
            let bounds = elementBounds(element)
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        return WorldRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func elementBounds(_ element: Element) -> WorldRect {
        switch element.type {
        case .stroke(let data):
            guard let first = data.points.first else {
                return .zero
            }
            var minX = first[0], minY = first[1]
            var maxX = first[0], maxY = first[1]
            for p in data.points {
                minX = min(minX, p[0])
                minY = min(minY, p[1])
                maxX = max(maxX, p[0])
                maxY = max(maxY, p[1])
            }
            let pad = data.thickness / 2
            return WorldRect(x: minX - pad, y: minY - pad,
                             width: maxX - minX + data.thickness,
                             height: maxY - minY + data.thickness)

        case .shape(let data):
            return WorldRect(x: data.origin[0], y: data.origin[1],
                             width: data.size[0], height: data.size[1])

        case .text(let data):
            return WorldRect(x: data.position[0], y: data.position[1],
                             width: 200, height: data.fontSize * 1.5)

        case .image(let data):
            return WorldRect(x: data.origin[0], y: data.origin[1],
                             width: data.size[0], height: data.size[1])
        }
    }
}
