import AppKit

struct CodableColor: Codable, Equatable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    var nsColor: NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    var cgColor: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.r = Double(c.redComponent)
        self.g = Double(c.greenComponent)
        self.b = Double(c.blueComponent)
        self.a = Double(c.alphaComponent)
    }

    static let black = CodableColor(r: 0, g: 0, b: 0)
    static let white = CodableColor(r: 1, g: 1, b: 1)
    static let red = CodableColor(r: 0.92, g: 0.26, b: 0.21)
    static let blue = CodableColor(r: 0.13, g: 0.59, b: 0.95)
    static let green = CodableColor(r: 0.30, g: 0.69, b: 0.31)
    static let orange = CodableColor(r: 1.0, g: 0.60, b: 0.0)
    static let purple = CodableColor(r: 0.61, g: 0.15, b: 0.69)
    static let yellow = CodableColor(r: 1.0, g: 0.92, b: 0.23)

    static let palette: [CodableColor] = [.black, .red, .blue, .green, .orange, .purple, .white]

    var accessibilityName: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        default: return "Custom color"
        }
    }
}
