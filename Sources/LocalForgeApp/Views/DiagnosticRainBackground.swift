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

    private let tokenWidth = 6
    private let tokens = [
        "let", "var", "func", "struct", "enum", "await", "return", "state",
        "cd", "git", "swift", "build", "test", "codesign", "status", "diff",
        "{", "}", "[", "]", ":", "true", "false", "null",
        "0xA7F2", "0x4A3F", "FF91", "3C7A", "A42F", "7D9C",
        "0101", "1100", "1010", "0011",
        "==", "!=", "&&", "||", "->", "=>",
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
        if colorScheme == .light { opacity *= 0.35 }
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
                    .foregroundStyle(Color.primary.opacity(alpha))
                context.draw(text, at: CGPoint(x: x, y: y), anchor: .topLeading)
            }
        }
    }

    private func token(forColumn column: Int, virtualRow: Int, variant: Int) -> String {
        let mixed = column &* 97 &+ virtualRow &* 31 &+ variant &* 13
        let raw = tokens[positiveModulo(mixed, tokens.count)]
        let clipped = String(raw.prefix(tokenWidth))
        if clipped.count >= tokenWidth { return clipped }
        return clipped + String(repeating: " ", count: tokenWidth - clipped.count)
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
            length: 8 + positiveModulo(column * 5, 9),
            phase: positiveModulo(column * 19, 80),
            brightness: 0.55 + Double(positiveModulo(column * 23, 45)) / 100,
            fontSize: 8.0 + CGFloat(positiveModulo(column * 7, 2))
        )
    }

    private func opacity(forTrail trail: Int, length: Int, brightness: Double) -> Double {
        if trail == 0 { return min(1, brightness * 1.55) }
        let remaining = 1.0 - Double(trail) / Double(max(length, 1))
        return max(0.11, remaining * remaining * brightness * 1.2)
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
        case .low: 0.06
        case .medium: 0.10
        case .high: 0.14
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
        case .sparse: 58
        case .balanced: 46
        case .dense: 38
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .sparse: 17.5
        case .balanced: 15.5
        case .dense: 14
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
        case .sparse: 0.18
        case .balanced: 0.25
        case .dense: 0.30
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
