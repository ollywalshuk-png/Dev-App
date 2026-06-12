import AppKit
import LocalForgeCore
import MetalKit
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
            Group {
                if DiagnosticRainMetalView.isAvailable {
                    DiagnosticRainMetalView(
                        config: DiagnosticRainMetalConfig(
                            intensity: intensity,
                            density: density,
                            motion: motion,
                            reduceMotion: reduceMotion,
                            colorScheme: colorScheme
                        )
                    )
                    .allowsHitTesting(false)
                } else {
                    SwiftUI.TimelineView(.animation(minimumInterval: intensity.frameInterval, paused: reduceMotion || motion == .still)) { timeline in
                        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                            drawRain(context: &context, size: size, date: effectiveDate(timeline.date))
                        }
                        .allowsHitTesting(false)
                        .drawingGroup(opaque: false, colorMode: .linear)
                    }
                }
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

private struct DiagnosticRainMetalConfig: Equatable {
    var intensity: DiagnosticBackgroundIntensity
    var density: DiagnosticBackgroundDensity
    var motion: DiagnosticBackgroundMotion
    var reduceMotion: Bool
    var colorScheme: ColorScheme

    var isStatic: Bool {
        reduceMotion || motion == .still
    }

    var framesPerSecond: Int {
        switch intensity {
        case .off: 1
        case .low: 30
        case .medium: 45
        case .high: 60
        }
    }
}

private struct DiagnosticRainMetalView: NSViewRepresentable {
    static let isAvailable = MTLCreateSystemDefaultDevice() != nil

    var config: DiagnosticRainMetalConfig

    func makeCoordinator() -> Coordinator {
        Coordinator(config: config)
    }

    func makeNSView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: device)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.preferredFramesPerSecond = config.framesPerSecond
        view.isPaused = config.isStatic
        view.enableSetNeedsDisplay = config.isStatic
        context.coordinator.attach(to: view, device: device)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(config: config, view: view)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var config: DiagnosticRainMetalConfig
        private var renderer: DiagnosticRainMetalRenderer?

        init(config: DiagnosticRainMetalConfig) {
            self.config = config
        }

        @MainActor
        func attach(to view: MTKView, device: MTLDevice?) {
            guard let device else { return }
            renderer = DiagnosticRainMetalRenderer(device: device, pixelFormat: view.colorPixelFormat, config: config)
            view.delegate = self
        }

        @MainActor
        func update(config: DiagnosticRainMetalConfig, view: MTKView) {
            self.config = config
            renderer?.config = config
            view.preferredFramesPerSecond = config.framesPerSecond
            view.isPaused = config.isStatic
            view.enableSetNeedsDisplay = config.isStatic
            if config.isStatic {
                view.needsDisplay = true
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            MainActor.assumeIsolated {
                guard
                    let drawable = view.currentDrawable,
                    let descriptor = view.currentRenderPassDescriptor,
                    view.drawableSize.width > 0,
                    view.drawableSize.height > 0
                else {
                    return
                }

                renderer?.draw(drawable: drawable, descriptor: descriptor, size: view.drawableSize)
            }
        }
    }
}

private final class DiagnosticRainMetalRenderer {
    var config: DiagnosticRainMetalConfig

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let atlas: DiagnosticRainGlyphAtlas
    private var instances: [DiagnosticRainMetalInstance] = []

    init?(device: MTLDevice, pixelFormat: MTLPixelFormat, config: DiagnosticRainMetalConfig) {
        self.device = device
        self.config = config

        guard
            let commandQueue = device.makeCommandQueue(),
            let atlas = DiagnosticRainGlyphAtlas(device: device),
            let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
            let vertex = library.makeFunction(name: "rainVertex"),
            let fragment = library.makeFunction(name: "rainFragment")
        else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge

        guard
            let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor),
            let sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        else {
            return nil
        }

        self.commandQueue = commandQueue
        self.pipeline = pipeline
        self.sampler = sampler
        self.atlas = atlas
    }

    func draw(drawable: any CAMetalDrawable, descriptor: MTLRenderPassDescriptor, size: CGSize) {
        buildInstances(size: size)
        guard !instances.isEmpty else { return }

        var uniforms = DiagnosticRainMetalUniforms(
            viewport: SIMD2<Float>(
                Float(size.width),
                Float(size.height)
            )
        )

        guard
            let instanceBuffer = device.makeBuffer(
                bytes: instances,
                length: MemoryLayout<DiagnosticRainMetalInstance>.stride * instances.count,
                options: .storageModeShared
            ),
            let uniformBuffer = device.makeBuffer(
                bytes: &uniforms,
                length: MemoryLayout<DiagnosticRainMetalUniforms>.stride,
                options: .storageModeShared
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(atlas.texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func buildInstances(size: CGSize) {
        instances.removeAll(keepingCapacity: true)

        let columnWidth = config.density.columnWidth
        let rowHeight = config.density.rowHeight
        let columns = min(max(Int(size.width / columnWidth) + 2, 1), config.density.maxColumns)
        let rows = min(max(Int(size.height / rowHeight) + 4, 1), config.density.maxRows)
        let seconds = config.isStatic ? 0 : Date().timeIntervalSinceReferenceDate

        instances.reserveCapacity(columns * min(rows, 72))

        for column in 0..<columns {
            let stream = streamProfile(for: column)
            let scrollRows = seconds * stream.rowsPerSecond * config.motion.multiplier
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

                let token = token(forColumn: column, virtualRow: virtualRow, variant: trail ?? 99)
                let alpha = isStream
                    ? opacity(forTrail: trail ?? 0, length: stream.length, brightness: stream.brightness)
                    : config.density.ambientAlpha * stream.brightness

                instances.append(
                    DiagnosticRainMetalInstance(
                        origin: SIMD2<Float>(Float(x), Float(y)),
                        size: SIMD2<Float>(Float(columnWidth), Float(rowHeight)),
                        uv: atlas.uv(for: token),
                        color: color(column: column, trail: trail, alpha: alpha)
                    )
                )
            }
        }
    }

    private func color(column: Int, trail: Int?, alpha: Double) -> SIMD4<Float> {
        let hue = streamHue(for: column)
        let isAmbient = trail == nil
        let isHead = trail == 0
        let saturation: Double
        let brightness: Double

        switch config.colorScheme {
        case .light:
            saturation = isAmbient ? 0.46 : isHead ? 0.78 : 0.62
            brightness = isHead ? 0.48 : 0.38
        case .dark:
            saturation = isAmbient ? 0.62 : isHead ? 0.92 : 0.78
            brightness = isHead ? 1.00 : 0.90
        @unknown default:
            saturation = 0
            brightness = 1
        }

        let rgb = Self.rgb(hue: hue, saturation: saturation, brightness: brightness)
        return SIMD4<Float>(Float(rgb.0), Float(rgb.1), Float(rgb.2), Float(alpha))
    }

    private static func rgb(hue: Double, saturation: Double, brightness: Double) -> (Double, Double, Double) {
        let h = hue * 6
        let i = floor(h)
        let f = h - i
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))

        switch Int(i).positiveModulo(6) {
        case 0: return (brightness, t, p)
        case 1: return (q, brightness, p)
        case 2: return (p, brightness, t)
        case 3: return (p, q, brightness)
        case 4: return (t, p, brightness)
        default: return (brightness, p, q)
        }
    }

    private func token(forColumn column: Int, virtualRow: Int, variant: Int) -> String {
        let group = tokenGroup(forColumn: column, virtualRow: virtualRow, variant: variant)
        let mixed = column &* 97 &+ virtualRow &* 31 &+ variant &* 13
        let raw = group[positiveModulo(mixed, group.count)]
        return Self.laneToken(raw)
    }

    private func tokenGroup(forColumn column: Int, virtualRow: Int, variant: Int) -> [String] {
        let selector = positiveModulo(column &* 41 &+ virtualRow &* 7 &+ variant &* 17, 100)
        switch selector {
        case 0..<19: return Self.swiftTokens
        case 19..<33: return Self.shellTokens
        case 33..<45: return Self.jsonTokens
        case 45..<60: return Self.hexBinaryTokens
        case 60..<72: return Self.operatorTokens
        case 72..<92: return Self.multilingualTokens
        default: return Self.technicalSymbols
        }
    }

    private func trailIndex(forScreenRow row: Double, head: Double, length: Int, rows: Int) -> Int? {
        let distance = positiveModulo(head - row, Double(rows))
        guard distance >= 0, distance < Double(length) else { return nil }
        return Int(distance.rounded(.down))
    }

    private func drawsAmbient(column: Int, virtualRow: Int) -> Bool {
        positiveModulo(column &* 53 &+ virtualRow &* 97, 100) < config.density.ambientCoverage
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

    private func streamHue(for column: Int) -> Double {
        switch positiveModulo(column * 17, 8) {
        case 0: return 0.43
        case 1: return 0.50
        case 2: return 0.57
        case 3: return 0.63
        case 4: return 0.74
        case 5: return 0.14
        case 6: return 0.83
        default: return 0.03
        }
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

    static func laneToken(_ raw: String) -> String {
        let sanitized = raw.filter { !$0.isWhitespace && !$0.isNewline }
        let clipped = String(sanitized.prefix(tokenWidth))
        return clipped.isEmpty ? "·" : clipped
    }

    static var atlasTokens: [String] {
        let allTokens = swiftTokens + shellTokens + jsonTokens + hexBinaryTokens + operatorTokens + multilingualTokens + technicalSymbols
        return Array(Set(allTokens.map(laneToken))).sorted()
    }

    private static let tokenWidth = 7
    private static let swiftTokens = [
        "let", "var", "func", "struct", "enum", "await", "return", "import",
        "actor", "async", "guard", "Task", "state", "truth", "verify", "risk",
        "release", "evid",
    ]
    private static let shellTokens = [
        "git", "swift", "build", "test", "cd", "grep", "codesign", "xcode",
        "auval", "status", "diff", "log", "zsh", "find", "open",
    ]
    private static let jsonTokens = [
        "{}", "[]", ":", "true", "false", "null", "\"id\"", "\"ok\"", "\"v\"",
    ]
    private static let hexBinaryTokens = [
        "0xA7F2", "0x4A3F", "FF91", "3C7A", "A42F", "7D9C", "0101", "1100",
        "1010", "0011", "0x19D4", "E7B0", "1001", "0110",
    ]
    private static let operatorTokens = [
        "==", "!=", "&&", "||", "->", "=>", "::", "??", "<=", ">=", "...", "|>",
    ]
    private static let multilingualTokens = [
        "かな", "カナ", "字", "型", "値", "数", "光", "音", "列", "層",
        "码", "流", "点", "形", "源", "层", "序", "节", "图", "量",
        "код", "тест", "тип", "узел", "мод", "сиг", "ряд",
        "한", "글", "코드", "값", "형", "빛", "열", "점",
        "λ", "π", "Ω", "Δ", "Σ", "φ", "θ", "α", "β", "γ",
        "ا", "ب", "م", "ن", "س", "ك", "ل", "ر",
        "é", "ñ", "å", "ø", "ç", "ü", "ß", "ï",
    ]
    private static let technicalSymbols = [
        "∑", "∂", "≈", "≤", "≥", "∞", "µ", "⌘", "⌥", "⟂", "◇", "◌",
        "∴", "∵", "⊕", "⊗", "⎇", "⌁",
    ]

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct RainInstance {
        float2 origin;
        float2 size;
        float4 uv;
        float4 color;
    };

    struct RainUniforms {
        float2 viewport;
    };

    struct RainVertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
    };

    vertex RainVertexOut rainVertex(
        uint vertexID [[vertex_id]],
        uint instanceID [[instance_id]],
        const device RainInstance *instances [[buffer(0)]],
        constant RainUniforms &uniforms [[buffer(1)]]
    ) {
        constexpr float2 corners[6] = {
            float2(0.0, 0.0),
            float2(1.0, 0.0),
            float2(0.0, 1.0),
            float2(1.0, 0.0),
            float2(1.0, 1.0),
            float2(0.0, 1.0)
        };

        RainInstance instance = instances[instanceID];
        float2 corner = corners[vertexID];
        float2 pixelPosition = instance.origin + corner * instance.size;
        float2 clipPosition = float2(
            pixelPosition.x / uniforms.viewport.x * 2.0 - 1.0,
            1.0 - pixelPosition.y / uniforms.viewport.y * 2.0
        );

        RainVertexOut out;
        out.position = float4(clipPosition, 0.0, 1.0);
        out.uv = mix(instance.uv.xy, instance.uv.zw, corner);
        out.color = instance.color;
        return out;
    }

    fragment half4 rainFragment(
        RainVertexOut in [[stage_in]],
        texture2d<float> atlas [[texture(0)]],
        sampler atlasSampler [[sampler(0)]]
    ) {
        float alpha = atlas.sample(atlasSampler, in.uv).a;
        return half4(half3(in.color.rgb), half(in.color.a * alpha));
    }
    """
}

private struct DiagnosticRainMetalInstance {
    var origin: SIMD2<Float>
    var size: SIMD2<Float>
    var uv: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct DiagnosticRainMetalUniforms {
    var viewport: SIMD2<Float>
}

private final class DiagnosticRainGlyphAtlas {
    let texture: MTLTexture

    private let uvs: [String: SIMD4<Float>]
    private let fallbackUV: SIMD4<Float>

    init?(device: MTLDevice) {
        let tokens = DiagnosticRainMetalRenderer.atlasTokens
        let cellWidth: CGFloat = 84
        let cellHeight: CGFloat = 28
        let columns = 12
        let rows = max(1, Int(ceil(Double(tokens.count) / Double(columns))))
        let atlasSize = NSSize(
            width: CGFloat(columns) * cellWidth,
            height: CGFloat(rows) * cellHeight
        )
        let image = NSImage(size: atlasSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: atlasSize).fill()

        var nextUVs: [String: SIMD4<Float>] = [:]
        nextUVs.reserveCapacity(tokens.count)

        for (index, token) in tokens.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = CGFloat(column) * cellWidth
            let y = atlasSize.height - CGFloat(row + 1) * cellHeight
            let drawRect = NSRect(x: x + 4, y: y + 4, width: cellWidth - 8, height: cellHeight - 8)
            token.draw(in: drawRect, withAttributes: attributes)

            let minX = Float(x / atlasSize.width)
            let maxX = Float((x + cellWidth) / atlasSize.width)
            let minY = Float(CGFloat(row) * cellHeight / atlasSize.height)
            let maxY = Float(CGFloat(row + 1) * cellHeight / atlasSize.height)
            nextUVs[token] = SIMD4<Float>(minX, minY, maxX, maxY)
        }

        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let loader = MTKTextureLoader(device: device)
        guard let texture = try? loader.newTexture(
            cgImage: cgImage,
            options: [
                MTKTextureLoader.Option.SRGB: false,
                MTKTextureLoader.Option.allocateMipmaps: false,
            ]
        ) else {
            return nil
        }

        self.texture = texture
        self.uvs = nextUVs
        self.fallbackUV = nextUVs[tokens.first ?? "·"] ?? SIMD4<Float>(0, 0, 1, 1)
    }

    func uv(for token: String) -> SIMD4<Float> {
        uvs[token] ?? fallbackUV
    }
}

private extension Int {
    func positiveModulo(_ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let result = self % modulus
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
