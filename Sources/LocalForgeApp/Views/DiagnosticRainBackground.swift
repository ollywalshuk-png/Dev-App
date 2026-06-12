import LocalForgeCore
import SwiftUI

struct DiagnosticRainBackground: View {
    var isEnabled: Bool
    var intensity: DiagnosticBackgroundIntensity
    var density: DiagnosticBackgroundDensity
    var motion: DiagnosticBackgroundMotion
    var reduceWhenInactive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private let tokenWidth = 7
    private let swiftTokens = [
        "let", "var", "func", "struct", "enum", "await", "return", "import",
        "actor", "async", "guard", "Task", "state", "truth", "verify", "risk",
        "release", "evid",
    ]
    private let shellTokens = [
        "git", "swift", "build", "test", "cd", "grep", "codesign", "xcode",
        "auval", "status", "diff", "log", "zsh", "find", "open",
    ]
    private let jsonTokens = [
        "{}", "[]", ":", "true", "false", "null", "\"id\"", "\"ok\"", "\"v\"",
    ]
    private let hexBinaryTokens = [
        "0xA7F2", "0x4A3F", "FF91", "3C7A", "A42F", "7D9C", "0101", "1100",
        "1010", "0011", "0x19D4", "E7B0", "1001", "0110",
    ]
    private let operatorTokens = [
        "==", "!=", "&&", "||", "->", "=>", "::", "??", "<=", ">=", "...", "|>",
    ]
    private let multilingualTokens = [
        "かな", "カナ", "字", "型", "値", "数", "光", "音", "列", "層",
        "码", "流", "点", "形", "源", "层", "序", "节", "图", "量",
        "код", "тест", "тип", "узел", "мод", "сиг", "ряд",
        "한", "글", "코드", "값", "형", "빛", "열", "점",
        "λ", "π", "Ω", "Δ", "Σ", "φ", "θ", "α", "β", "γ",
        "ا", "ب", "م", "ن", "س", "ك", "ل", "ر",
        "é", "ñ", "å", "ø", "ç", "ü", "ß", "ï",
    ]
    private let technicalSymbols = [
        "∑", "∂", "≈", "≤", "≥", "∞", "µ", "⌘", "⌥", "⟂", "◇", "◌",
        "∴", "∵", "⊕", "⊗", "⎇", "⌁",
    ]

    var body: some View {
        if isEnabled && intensity != .off {
            SwiftUI.TimelineView(.animation(minimumInterval: intensity.frameInterval, paused: reduceMotion || motion == .still)) { timeline in
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    drawRain(context: &context, size: size, date: effectiveDate(timeline.date))
                }
                .allowsHitTesting(false)
                .drawingGroup(opaque: false, colorMode: .linear)
            }
            .opacity(effectiveOpacity)
        }
    }

    private var effectiveOpacity: Double {
        var opacity = intensity.opacity
        if colorScheme == .light { opacity *= 0.76 }
        if reduceWhenInactive && scenePhase != .active { opacity *= 0.28 }
        return opacity
    }

    private func effectiveDate(_ date: Date) -> Date {
        reduceMotion ? Date(timeIntervalSinceReferenceDate: 0) : date
    }

    private func drawRain(context: inout GraphicsContext, size: CGSize, date: Date) {
        let columnWidth = density.columnWidth
        let rowHeight = density.rowHeight
        let columns = min(max(Int(size.width / columnWidth) + 2, 1), density.maxColumns)
        let rows = min(max(Int(size.height / rowHeight) + 4, 1), density.maxRows)
        let seconds = date.timeIntervalSinceReferenceDate

        for column in 0..<columns {
            let stream = streamProfile(for: column)
            let scrollRows = seconds * stream.rowsPerSecond * motion.multiplier
            let baseRow = Int(scrollRows.rounded(.down))
            let fractionalRow = scrollRows - Double(baseRow)
            let yOffset = CGFloat(fractionalRow) * rowHeight
            let head = positiveModulo(scrollRows + Double(stream.phase), Double(rows + stream.length))
            let x = CGFloat(column) * columnWidth

            for screenRow in -1..<rows {
                let y = CGFloat(screenRow) * rowHeight + yOffset
                guard y > -rowHeight, y < size.height + rowHeight else { continue }

                let virtualRow = screenRow - baseRow
                let trail = trailIndex(
                    forScreenRow: Double(screenRow) + fractionalRow,
                    head: head,
                    length: stream.length,
                    rows: rows
                )
                let isStream = trail != nil
                guard isStream || drawsAmbient(column: column, virtualRow: virtualRow) else { continue }

                let token = token(
                    forColumn: column,
                    virtualRow: virtualRow,
                    variant: trail ?? 99
                )
                let alpha = isStream
                    ? opacity(forTrail: trail ?? 0, length: stream.length, brightness: stream.brightness)
                    : density.ambientAlpha * stream.brightness
                let text = Text(token)
                    .font(.system(size: stream.fontSize, weight: trail == 0 ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(tokenColor(column: column, trail: trail, alpha: alpha))
                context.draw(text, at: CGPoint(x: x, y: y), anchor: .topLeading)
            }
        }
    }

    private func tokenColor(column: Int, trail: Int?, alpha: Double) -> Color {
        let hue = streamHue(for: column)
        let isAmbient = trail == nil
        let isHead = trail == 0

        switch colorScheme {
        case .light:
            return Color(
                hue: hue,
                saturation: isAmbient ? 0.46 : isHead ? 0.78 : 0.62,
                brightness: isHead ? 0.48 : 0.38,
                opacity: alpha
            )
        case .dark:
            return Color(
                hue: hue,
                saturation: isAmbient ? 0.62 : isHead ? 0.92 : 0.78,
                brightness: isHead ? 1.00 : 0.90,
                opacity: alpha
            )
        @unknown default:
            return Color.primary.opacity(alpha)
        }
    }

    private func streamHue(for column: Int) -> Double {
        switch positiveModulo(column * 17, 8) {
        case 0: return 0.43 // green
        case 1: return 0.50 // cyan
        case 2: return 0.57 // blue
        case 3: return 0.63 // indigo
        case 4: return 0.74 // violet
        case 5: return 0.14 // amber
        case 6: return 0.83 // magenta
        default: return 0.03 // red-orange
        }
    }

    private func token(forColumn column: Int, virtualRow: Int, variant: Int) -> String {
        let group = tokenGroup(forColumn: column, virtualRow: virtualRow, variant: variant)
        let mixed = column &* 97 &+ virtualRow &* 31 &+ variant &* 13
        let raw = group[positiveModulo(mixed, group.count)]
        return laneToken(raw)
    }

    private func laneToken(_ raw: String) -> String {
        let sanitized = raw
            .filter { !$0.isWhitespace && !$0.isNewline }
        let clipped = String(sanitized.prefix(tokenWidth))
        if clipped.count >= tokenWidth { return clipped }
        return clipped + String(repeating: " ", count: tokenWidth - clipped.count)
    }

    private func tokenGroup(forColumn column: Int, virtualRow: Int, variant: Int) -> [String] {
        let selector = positiveModulo(column &* 41 &+ virtualRow &* 7 &+ variant &* 17, 100)
        switch selector {
        case 0..<19: return swiftTokens
        case 19..<33: return shellTokens
        case 33..<45: return jsonTokens
        case 45..<60: return hexBinaryTokens
        case 60..<72: return operatorTokens
        case 72..<92: return multilingualTokens
        default: return technicalSymbols
        }
    }

    private func trailIndex(forScreenRow row: Double, head: Double, length: Int, rows: Int) -> Int? {
        let distance = positiveModulo(head - row, Double(rows))
        guard distance >= 0, distance < Double(length) else { return nil }
        return Int(distance.rounded(.down))
    }

    private func drawsAmbient(column: Int, virtualRow: Int) -> Bool {
        positiveModulo(column &* 53 &+ virtualRow &* 97, 100) < density.ambientCoverage
    }

    private func streamProfile(for column: Int) -> StreamProfile {
        let bucket = positiveModulo(column * 37, 100)
        let rowsPerSecond: Double
        if bucket < 80 {
            rowsPerSecond = 0.24 + Double(positiveModulo(column * 11, 22)) / 100
        } else if bucket < 95 {
            rowsPerSecond = 0.46 + Double(positiveModulo(column * 13, 26)) / 100
        } else {
            rowsPerSecond = 0.72 + Double(positiveModulo(column * 17, 34)) / 100
        }

        return StreamProfile(
            rowsPerSecond: rowsPerSecond,
            length: 11 + positiveModulo(column * 5, 11),
            phase: positiveModulo(column * 19, 80),
            brightness: 0.76 + Double(positiveModulo(column * 23, 42)) / 100,
            fontSize: 9.2 + CGFloat(positiveModulo(column * 7, 3)) * 0.45
        )
    }

    private func opacity(forTrail trail: Int, length: Int, brightness: Double) -> Double {
        if trail == 0 { return min(1, brightness * 1.75) }
        let remaining = 1.0 - Double(trail) / Double(max(length, 1))
        return max(0.20, remaining * remaining * brightness * 1.58)
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let result = value % modulus
        return result >= 0 ? result : result + modulus
    }

    private func positiveModulo(_ value: Double, _ modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let result = value.truncatingRemainder(dividingBy: modulus)
        return result >= 0 ? result : result + modulus
    }
}

private struct StreamProfile {
    var rowsPerSecond: Double
    var length: Int
    var phase: Int
    var brightness: Double
    var fontSize: CGFloat
}

extension DiagnosticBackgroundIntensity {
    var opacity: Double {
        switch self {
        case .off: 0
        case .low: 0.14
        case .medium: 0.25
        case .high: 0.38
        }
    }

    var frameInterval: TimeInterval {
        switch self {
        case .off: 1.0
        case .low: 1.0 / 30.0
        case .medium: 1.0 / 45.0
        case .high: 1.0 / 60.0
        }
    }
}

extension DiagnosticBackgroundDensity {
    var columnWidth: CGFloat {
        switch self {
        case .sparse: 60
        case .balanced: 50
        case .dense: 44
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .sparse: 18
        case .balanced: 16
        case .dense: 14.5
        }
    }

    var maxColumns: Int {
        switch self {
        case .sparse: 64
        case .balanced: 94
        case .dense: 120
        }
    }

    var maxRows: Int {
        switch self {
        case .sparse: 100
        case .balanced: 132
        case .dense: 160
        }
    }

    var ambientAlpha: Double {
        switch self {
        case .sparse: 0.32
        case .balanced: 0.44
        case .dense: 0.52
        }
    }

    var ambientCoverage: Int {
        switch self {
        case .sparse: 42
        case .balanced: 58
        case .dense: 72
        }
    }
}

extension DiagnosticBackgroundMotion {
    var multiplier: Double {
        switch self {
        case .still: 0
        case .slow: 1
        case .medium: 1.55
        }
    }
}
