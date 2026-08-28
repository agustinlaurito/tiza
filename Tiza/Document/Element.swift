import Foundation

struct Element: Codable, Identifiable, Equatable {
    var id: UUID
    var type: ElementType
    var zIndex: Int
    var locked: Bool = false
    var opacity: Double = 1.0
    var groupId: UUID? = nil

    init(id: UUID = UUID(), type: ElementType, zIndex: Int,
         locked: Bool = false, opacity: Double = 1.0, groupId: UUID? = nil) {
        self.id = id
        self.type = type
        self.zIndex = zIndex
        self.locked = locked
        self.opacity = opacity
        self.groupId = groupId
    }
}

enum ElementType: Codable, Equatable {
    case stroke(StrokeData)
    case shape(ShapeData)
    case text(TextData)
    case image(ImageData)
    case connector(ConnectorData)
    case table(TableData)
    case equation(EquationData)
}

enum StrokeStyle: String, Codable, Equatable {
    case pen
    case highlighter
}

enum DashStyle: String, Codable, Equatable, CaseIterable {
    case solid
    case dashed
    case dotted

    var displayName: String {
        switch self {
        case .solid: "Solid"
        case .dashed: "Dashed"
        case .dotted: "Dotted"
        }
    }

    var systemImage: String {
        switch self {
        case .solid: "line.diagonal"
        case .dashed: "line.horizontal.star.fill.line.horizontal"
        case .dotted: "ellipsis"
        }
    }
}

struct StrokeData: Codable, Equatable {
    var points: [[Double]]
    var color: CodableColor
    var thickness: Double
    var style: StrokeStyle
    var dashStyle: DashStyle = .solid
    var pressures: [Double]?
}

enum ShapeType: String, Codable, Equatable {
    case rectangle
    case ellipse
    case line
    case arrow
    case triangle
    case diamond
    case star
}

struct ShapeData: Codable, Equatable {
    var shapeType: ShapeType
    var origin: [Double]
    var size: [Double]
    var rotation: Double
    var strokeColor: CodableColor
    var fillColor: CodableColor?
    var strokeWidth: Double
    var dashStyle: DashStyle = .solid
    var label: String?
}

enum FontStyle: String, Codable, Equatable, CaseIterable {
    case system
    case serif
    case rounded

    var displayName: String {
        switch self {
        case .system: "Default"
        case .serif: "Serif"
        case .rounded: "Rounded"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "textformat"
        case .serif: "text.book.closed"
        case .rounded: "paintbrush.pointed"
        }
    }
}

enum TextPreset: String, Codable, Equatable, CaseIterable {
    case h1, h2, h3, body

    var displayName: String {
        switch self {
        case .h1: "Heading 1"
        case .h2: "Heading 2"
        case .h3: "Heading 3"
        case .body: "Body"
        }
    }

    var shortName: String {
        switch self {
        case .h1: "H1"
        case .h2: "H2"
        case .h3: "H3"
        case .body: "Body"
        }
    }

    var fontSize: Double {
        switch self {
        case .h1: 48
        case .h2: 36
        case .h3: 28
        case .body: 18
        }
    }

    var isBold: Bool {
        switch self {
        case .h1, .h2, .h3: true
        case .body: false
        }
    }
}

struct TextData: Codable, Equatable {
    var position: [Double]
    var content: String
    var fontSize: Double
    var color: CodableColor
    var bold: Bool
    var rotation: Double
    var fontStyle: FontStyle = .system
    var underline: Bool = false
    var width: Double?
}

enum AlignmentMode: String, CaseIterable {
    case left, centerH, right, top, centerV, bottom, distributeH, distributeV

    var displayName: String {
        switch self {
        case .left: "Left"
        case .centerH: "Center"
        case .right: "Right"
        case .top: "Top"
        case .centerV: "Middle"
        case .bottom: "Bottom"
        case .distributeH: "Distribute H"
        case .distributeV: "Distribute V"
        }
    }

    var systemImage: String {
        switch self {
        case .left: "align.horizontal.left"
        case .centerH: "align.horizontal.center"
        case .right: "align.horizontal.right"
        case .top: "align.vertical.top"
        case .centerV: "align.vertical.center"
        case .bottom: "align.vertical.bottom"
        case .distributeH: "distribute.horizontal.center"
        case .distributeV: "distribute.vertical.center"
        }
    }
}

struct ImageData: Codable, Equatable {
    var assetId: String
    var origin: [Double]
    var size: [Double]
    var rotation: Double
}

enum ConnectorLineType: String, Codable, Equatable {
    case straight
    case curved
}

struct ConnectorData: Codable, Equatable {
    var sourceElementId: UUID?
    var targetElementId: UUID?
    var sourcePoint: [Double]
    var targetPoint: [Double]
    var strokeColor: CodableColor
    var strokeWidth: Double
    var dashStyle: DashStyle = .solid
    var lineType: ConnectorLineType = .straight
    var hasSourceArrow: Bool = false
    var hasTargetArrow: Bool = true
    var label: String?
}

struct TableData: Codable, Equatable {
    var origin: [Double]
    var rows: Int
    var columns: Int
    var cellWidth: Double = 100
    var cellHeight: Double = 32
    var cells: [[String]]
    var strokeColor: CodableColor
    var fontSize: Double = 14
    var headerRow: Bool = false

    static func empty(rows: Int, columns: Int, origin: [Double], color: CodableColor) -> TableData {
        let cells = Array(repeating: Array(repeating: "", count: columns), count: rows)
        return TableData(origin: origin, rows: rows, columns: columns,
                         cells: cells, strokeColor: color)
    }
}

struct EquationData: Codable, Equatable {
    var position: [Double]
    var latex: String
    var fontSize: Double
    var color: CodableColor
}
