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

struct TextData: Codable, Equatable {
    var position: [Double]
    var content: String
    var fontSize: Double
    var color: CodableColor
    var bold: Bool
    var rotation: Double
}

struct ImageData: Codable, Equatable {
    var assetId: String
    var origin: [Double]
    var size: [Double]
    var rotation: Double
}
