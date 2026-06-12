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
        "actor", "state", "truth", "verify", "risk", "release", "evid",
    ]
    private let shellTokens = [
        "git", "swift", "build", "test", "cd", "grep", "codesign", "xcode",
        "auval", "status", "diff", "log",
    ]
    private let jsonTokens = [
        "{}", "[]", ":", "true", "false", "null", "\"id\"", "\"ok\"",
    ]
    private let hexBinaryTokens = [
        "0xA7F2", "0x4A3F", "FF91", "3C7A", "A42F", "7D9C", "0101", "1100",
        "1010", "0011",
    ]
    private let operatorTokens = [
        "==", "!=", "&&", "||", "->", "=>", "::", "??", "<=", ">=",
    ]
    private let multilingualTokens = [
        "かな", "カナ", "字", "型", "値", "数", "光", "音",
        "数", "码", "流", "点", "形", "源", "层", "核",
        "код", "тест", "тип", "узел", "мод",
        "한", "글", "코드", "값", "형", "빛",
        "λ", "π", "Ω", "Δ", "Σ", "φ", "θ",
        "ا", "ب", "م", "ن", "س", "ك", "ل",
        "é", "ñ", "å", "ø", "ç", "ü", "ß",
    ]
    private let technicalSymbols = [
        "∑", "∂", "≈", "≤", "≥", "∞", "µ", "⌘", "⌥", "⟂", "◇", "◌",
    ]

    var body: some View {
        if isEnabled && intensity != .off {
            SwiftUI.TimelineView(PeriodicTimelineSchedule(from: Date(), by: intensity.frameInterval)) { timeline in
                Canvas { context, size in
                    drawRain(context: &context, size: size, date: effectiveDate(timeline.date))
                }
                .allowsHitTesting(false)
            }
            .opacity(effectiveOpacity)
        }
    }

    private var effectiveOpacity: Double {
        var opacity = intensity.opacity
        if colorScheme == .light { opacity *= 0.68 }
        if reduceWhenInactive && scenePhase != .active { opacity *= 0.25 }
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
                saturation: isAmbient ? 0.38 : isHead ? 0.70 : 0.54,
                brightness: isHead ? 0.42 : 0.34,
                opacity: alpha
            )
        case .dark:
            return Color(
                hue: hue,
                saturation: isAmbient ? 0.52 : isHead ? 0.88 : 0.72,
                brightness: isHead ? 1.00 : 0.82,
                opacity: alpha
            )
        @unknown default:
            return Color.primary.opacity(alpha)
        }
    }

    private func streamHue(for column: Int) -> Double {
        switch positiveModulo(column * 17, 6) {
        case 0: return 0.43 // green
        case 1: return 0.50 // cyan
        case 2: return 0.57 // blue
        case 3: return 0.74 // violet
        case 4: return 0.14 // amber
        default: return 0.83 // magenta
        }
    }

    private func token(forColumn column: Int, virtualRow: Int, variant: Int) -> String {
        let group = tokenGroup(forColumn: column, virtualRow: virtualRow, variant: variant)
        let mixed = column &* 97 &+ virtualRow &* 31 &+ variant &* 13
        let raw = group[positiveModulo(mixed, group.count)]
        let clipped = String(raw.prefix(tokenWidth))
        if clipped.count >= tokenWidth { return clipped }
        return clipped + String(repeating: " ", count: tokenWidth - clipped.count)
    }

    private func tokenGroup(forColumn column: Int, virtualRow: Int, variant: Int) -> [String] {
        let selector = positiveModulo(column &* 41 &+ virtualRow &* 7 &+ variant &* 17, 100)
        switch selector {
        case 0..<18: return swiftTokens
        case 18..<32: return shellTokens
        case 32..<44: return jsonTokens
        case 44..<58: return hexBinaryTokens
        case 58..<70: return operatorTokens
        case 70..<90: return multilingualTokens
        default: return technicalSymbols
        }
    }

    private func trailIndex(forScreenRow row: Double, head: Double, length: Int, rows: Int) -> Int? {
        let distance = positiveModulo(head - row, Double(rows))
        guard distance >= 0, distance < Double(length) else { return nil }
        return Int(distance.rounded(.down))
    }

    private func streamProfile(for column: Int) -> StreamProfile {
        let bucket = positiveModulo(column * 37, 100)
        let rowsPerSecond: Double
        if bucket < 80 {
            rowsPerSecond = 0.16 + Double(positiveModulo(column * 11, 16)) / 100
        } else if bucket < 95 {
            rowsPerSecond = 0.28 + Double(positiveModulo(column * 13, 18)) / 100
        } else {
            rowsPerSecond = 0.42 + Double(positiveModulo(column * 17, 20)) / 100
        }

        return StreamProfile(
            rowsPerSecond: rowsPerSecond,
            length: 9 + positiveModulo(column * 5, 10),
            phase: positiveModulo(column * 19, 80),
            brightness: 0.70 + Double(positiveModulo(column * 23, 40)) / 100,
            fontSize: 8.8 + CGFloat(positiveModulo(column * 7, 2))
        )
    }

    private func opacity(forTrail trail: Int, length: Int, brightness: Double) -> Double {
        if trail == 0 { return min(1, brightness * 1.75) }
        let remaining = 1.0 - Double(trail) / Double(max(length, 1))
        return max(0.16, remaining * remaining * brightness * 1.45)
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
        case .low: 0.10
        case .medium: 0.18
        case .high: 0.28
        }
    }

    var frameInterval: TimeInterval {
        switch self {
        case .off: 1.0
        case .low: 0.25
        case .medium: 0.16
        case .high: 0.12
        }
    }
}

extension DiagnosticBackgroundDensity {
    var columnWidth: CGFloat {
        switch self {
        case .sparse: 66
        case .balanced: 54
        case .dense: 48
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .sparse: 19
        case .balanced: 17
        case .dense: 15.5
        }
    }

    var maxColumns: Int {
        switch self {
        case .sparse: 52
        case .balanced: 72
        case .dense: 88
        }
    }

    var maxRows: Int {
        switch self {
        case .sparse: 90
        case .balanced: 110
        case .dense: 128
        }
    }

    var ambientAlpha: Double {
        switch self {
        case .sparse: 0.26
        case .balanced: 0.34
        case .dense: 0.40
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
