import Foundation

struct Element: Codable, Identifiable, Equatable {
    var id: UUID
    var type: ElementType
    var zIndex: Int

    init(id: UUID = UUID(), type: ElementType, zIndex: Int) {
        self.id = id
        self.type = type
        self.zIndex = zIndex
    }
}

enum ElementType: Codable, Equatable {
    case stroke(StrokeData)
    case shape(ShapeData)
    case text(TextData)
    case image(ImageData)
}

enum StrokeStyle: String, Codable, Equatable {
    case pen
    case highlighter
}

struct StrokeData: Codable, Equatable {
    var points: [[Double]]
    var color: CodableColor
    var thickness: Double
    var style: StrokeStyle
}

enum ShapeType: String, Codable, Equatable {
    case rectangle
    case ellipse
    case line
    case arrow
}

struct ShapeData: Codable, Equatable {
    var shapeType: ShapeType
    var origin: [Double]
    var size: [Double]
    var rotation: Double
    var strokeColor: CodableColor
    var fillColor: CodableColor?
    var strokeWidth: Double
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
