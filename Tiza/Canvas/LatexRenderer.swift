import Foundation

enum LatexRenderer {
    private static let replacements: [(String, String)] = [
        ("\\alpha", "\u{03B1}"), ("\\beta", "\u{03B2}"), ("\\gamma", "\u{03B3}"),
        ("\\delta", "\u{03B4}"), ("\\epsilon", "\u{03B5}"), ("\\zeta", "\u{03B6}"),
        ("\\eta", "\u{03B7}"), ("\\theta", "\u{03B8}"), ("\\iota", "\u{03B9}"),
        ("\\kappa", "\u{03BA}"), ("\\lambda", "\u{03BB}"), ("\\mu", "\u{03BC}"),
        ("\\nu", "\u{03BD}"), ("\\xi", "\u{03BE}"), ("\\pi", "\u{03C0}"),
        ("\\rho", "\u{03C1}"), ("\\sigma", "\u{03C3}"), ("\\tau", "\u{03C4}"),
        ("\\upsilon", "\u{03C5}"), ("\\phi", "\u{03C6}"), ("\\chi", "\u{03C7}"),
        ("\\psi", "\u{03C8}"), ("\\omega", "\u{03C9}"),
        ("\\Alpha", "\u{0391}"), ("\\Beta", "\u{0392}"), ("\\Gamma", "\u{0393}"),
        ("\\Delta", "\u{0394}"), ("\\Theta", "\u{0398}"), ("\\Lambda", "\u{039B}"),
        ("\\Pi", "\u{03A0}"), ("\\Sigma", "\u{03A3}"), ("\\Phi", "\u{03A6}"),
        ("\\Psi", "\u{03A8}"), ("\\Omega", "\u{03A9}"),
        ("\\infty", "\u{221E}"), ("\\pm", "\u{00B1}"), ("\\times", "\u{00D7}"),
        ("\\div", "\u{00F7}"), ("\\neq", "\u{2260}"), ("\\leq", "\u{2264}"),
        ("\\geq", "\u{2265}"), ("\\approx", "\u{2248}"), ("\\equiv", "\u{2261}"),
        ("\\sum", "\u{2211}"), ("\\prod", "\u{220F}"), ("\\int", "\u{222B}"),
        ("\\partial", "\u{2202}"), ("\\nabla", "\u{2207}"), ("\\sqrt", "\u{221A}"),
        ("\\cdot", "\u{22C5}"), ("\\forall", "\u{2200}"), ("\\exists", "\u{2203}"),
        ("\\in", "\u{2208}"), ("\\notin", "\u{2209}"), ("\\subset", "\u{2282}"),
        ("\\supset", "\u{2283}"), ("\\cup", "\u{222A}"), ("\\cap", "\u{2229}"),
        ("\\emptyset", "\u{2205}"), ("\\rightarrow", "\u{2192}"),
        ("\\leftarrow", "\u{2190}"), ("\\Rightarrow", "\u{21D2}"),
        ("\\Leftarrow", "\u{21D0}"), ("\\leftrightarrow", "\u{2194}"),
        ("\\to", "\u{2192}"), ("\\degree", "\u{00B0}"),
    ]

    private static let superscripts: [Character: Character] = [
        "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}",
        "4": "\u{2074}", "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}",
        "8": "\u{2078}", "9": "\u{2079}", "+": "\u{207A}", "-": "\u{207B}",
        "n": "\u{207F}", "i": "\u{2071}",
    ]

    private static let subscripts: [Character: Character] = [
        "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}",
        "4": "\u{2084}", "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}",
        "8": "\u{2088}", "9": "\u{2089}", "+": "\u{208A}", "-": "\u{208B}",
    ]

    static func render(_ latex: String) -> String {
        var result = latex

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }

        result = processScripts(result, marker: "^", map: superscripts)
        result = processScripts(result, marker: "_", map: subscripts)

        result = result.replacingOccurrences(of: "\\frac{", with: "")
        result = result.replacingOccurrences(of: "}{", with: "/")

        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")
        result = result.replacingOccurrences(of: "\\", with: "")

        return result
    }

    private static func processScripts(_ input: String, marker: String,
                                        map: [Character: Character]) -> String {
        var result = ""
        var chars = input[input.startIndex...]
        while let range = chars.range(of: marker) {
            result += chars[chars.startIndex..<range.lowerBound]
            chars = chars[range.upperBound...]
            if chars.first == "{" {
                chars = chars[chars.index(after: chars.startIndex)...]
                while let c = chars.first, c != "}" {
                    result.append(map[c] ?? c)
                    chars = chars[chars.index(after: chars.startIndex)...]
                }
                if chars.first == "}" {
                    chars = chars[chars.index(after: chars.startIndex)...]
                }
            } else if let c = chars.first {
                result.append(map[c] ?? c)
                chars = chars[chars.index(after: chars.startIndex)...]
            }
        }
        result += chars
        return result
    }
}
