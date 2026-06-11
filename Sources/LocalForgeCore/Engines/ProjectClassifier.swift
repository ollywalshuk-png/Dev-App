import Foundation

/// Read-only project recognition. Walks a bounded slice of the project tree
/// looking for marker files, Audio Unit declarations, and source-code signals,
/// then names what the project actually is. No file is modified; nothing leaves
/// the machine.
public struct ProjectClassifier: Sendable {
    public init() {}

    private static let ignoredDirectories: Set<String> = [
        ".build", "DerivedData", "node_modules", ".git", "Pods", ".swiftpm", "vendor"
    ]
    private static let maxDepth = 3
    private static let maxEntries = 1_500
    private static let maxSourceReads = 60
    private static let maxSourceBytes = 256 * 1_024

    public func classify(rootURL: URL) -> ProjectIdentity {
        let markers = collectMarkers(at: rootURL)

        let hasXcodeProject = markers.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        let hasPackageSwift = markers.contains("Package.swift")
        let hasPackageJSON = markers.contains("package.json")
        let hasCargo = markers.contains("Cargo.toml")
        let hasGoMod = markers.contains("go.mod")
        let hasPython = markers.contains { ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"].contains($0) }
        let audioUnitType = detectAudioUnitType(at: rootURL)

        var ecosystems: [String] = []
        if hasXcodeProject { ecosystems.append("Xcode") }
        if hasPackageSwift { ecosystems.append("SwiftPM") }
        if markers.contains("Podfile") { ecosystems.append("CocoaPods") }
        if hasPackageJSON { ecosystems.append("Node") }
        if hasCargo { ecosystems.append("Cargo") }
        if hasGoMod { ecosystems.append("Go Modules") }
        if hasPython { ecosystems.append("Python") }

        let sortedMarkers = markers.sorted()

        // --- Audio Unit (most specific) ---
        if let auType = audioUnitType {
            let kind: ProjectKind
            let detail: String
            switch auType {
            case .instrument:
                kind = .audioUnitInstrument
                detail = "Audio Unit instrument markers were observed (AudioComponents type aumu/aumi). DSP, MIDI, the preset system, and AU validation are all in scope."
            case .effect:
                kind = .audioUnitEffect
                detail = "Audio Unit effect markers were observed (AudioComponents type aufx/aufc). DSP, the preset system, and AU validation are in scope; MIDI is optional."
            case .generic:
                kind = .audioUnitPlugin
                detail = "Audio Unit markers were observed, but the component type could not be classified as instrument or effect."
            }
            return ProjectIdentity(
                kind: kind,
                detail: detail,
                ecosystems: ecosystems.isEmpty ? ["Apple"] : ecosystems,
                markers: sortedMarkers,
                confidence: .inferred
            )
        }

        // --- Apple app / framework / CLI refinement ---
        if hasXcodeProject || hasPackageSwift {
            let signals = collectSwiftSignals(at: rootURL, hasPackageSwift: hasPackageSwift)
            if let appleKind = refineAppleKind(signals: signals, hasXcodeProject: hasXcodeProject, hasPackageSwift: hasPackageSwift) {
                return ProjectIdentity(
                    kind: appleKind.kind,
                    detail: appleKind.detail,
                    ecosystems: ecosystems,
                    markers: sortedMarkers,
                    confidence: appleKind.confidence
                )
            }
        }

        // --- Non-Apple ecosystems ---
        if hasPackageJSON {
            return ProjectIdentity(kind: .nodeWeb, detail: "A Node/web project manifest (package.json) is present.", ecosystems: ecosystems, markers: sortedMarkers, confidence: .observed)
        }
        if hasCargo {
            return ProjectIdentity(kind: .rustProject, detail: "A Rust manifest (Cargo.toml) is present.", ecosystems: ecosystems, markers: sortedMarkers, confidence: .observed)
        }
        if hasGoMod {
            return ProjectIdentity(kind: .goProject, detail: "A Go module (go.mod) is present.", ecosystems: ecosystems, markers: sortedMarkers, confidence: .observed)
        }
        if hasPython {
            return ProjectIdentity(kind: .pythonProject, detail: "Python project markers are present.", ecosystems: ecosystems, markers: sortedMarkers, confidence: .observed)
        }

        return ProjectIdentity(
            kind: .unidentified,
            detail: "No recognised project markers were observed at this root. It may not be a project root, or it uses an unsupported toolchain.",
            ecosystems: ecosystems,
            markers: sortedMarkers,
            confidence: .unknown
        )
    }

    // MARK: - Apple subtype refinement

    private struct SwiftSignals {
        var importsSwiftUI = false
        var importsAppKit = false
        var importsUIKit = false
        var hasAppProtocol = false        // `: App {` or `struct X: App`
        var hasUIApplicationMain = false
        var hasNSApplicationMain = false
        var hasMain = false               // `@main` or top-level main.swift
        var declaresExecutable = false    // Package.swift executableTarget/.executable
        var declaresLibraryOnly = false   // Package.swift only .library products
    }

    private func refineAppleKind(
        signals: SwiftSignals,
        hasXcodeProject: Bool,
        hasPackageSwift: Bool
    ) -> (kind: ProjectKind, detail: String, confidence: EvidenceClassification)? {
        if signals.hasAppProtocol || (signals.importsSwiftUI && signals.hasMain) {
            return (.swiftUIApp, "A SwiftUI `App` entry point was observed.", .inferred)
        }
        if signals.hasUIApplicationMain || (signals.importsUIKit && signals.hasMain) {
            return (.uiKitApp, "A UIKit application entry point (UIApplicationMain) was observed.", .inferred)
        }
        if signals.hasNSApplicationMain || (signals.importsAppKit && signals.hasMain && !signals.importsSwiftUI) {
            return (.appKitApp, "An AppKit application entry point (NSApplicationMain) was observed.", .inferred)
        }
        if signals.declaresExecutable && !signals.importsSwiftUI && !signals.importsAppKit && !signals.importsUIKit {
            return (.commandLineTool, "An executable Swift target with no UI framework imports was observed.", .inferred)
        }
        if hasPackageSwift && signals.declaresLibraryOnly && !signals.declaresExecutable {
            return (.swiftPackage, "A Swift package manifest with library products was observed.", .observed)
        }
        if hasPackageSwift {
            return (.swiftPackage, "A Swift package manifest (Package.swift) is present.", .observed)
        }
        if hasXcodeProject {
            return (.xcodeApp, "An Xcode project or workspace is present, but its product type could not be refined.", .observed)
        }
        return nil
    }

    private func collectSwiftSignals(at rootURL: URL, hasPackageSwift: Bool) -> SwiftSignals {
        var signals = SwiftSignals()
        var reads = 0

        walk(rootURL) { url, stop in
            let name = url.lastPathComponent
            if name == "Package.swift" {
                if let text = readBoundedText(url) {
                    if text.contains(".executableTarget") || text.contains(".executable(") { signals.declaresExecutable = true }
                    if text.contains(".library(") { signals.declaresLibraryOnly = true }
                }
                return
            }
            guard url.pathExtension == "swift", reads < Self.maxSourceReads else { return }
            if name == "main.swift" { signals.hasMain = true }
            guard let text = readBoundedText(url) else { return }
            reads += 1

            if text.contains("import SwiftUI") { signals.importsSwiftUI = true }
            if text.contains("import AppKit") { signals.importsAppKit = true }
            if text.contains("import UIKit") { signals.importsUIKit = true }
            if text.contains("@main") { signals.hasMain = true }
            if text.contains(": App {") || text.contains(":App{") || text.range(of: #"struct\s+\w+\s*:\s*App"#, options: .regularExpression) != nil {
                signals.hasAppProtocol = true
            }
            if text.contains("UIApplicationMain") || text.contains("@UIApplicationMain") { signals.hasUIApplicationMain = true }
            if text.contains("NSApplicationMain") || text.contains("@NSApplicationMain") { signals.hasNSApplicationMain = true }

            if signals.hasAppProtocol && signals.hasUIApplicationMain && signals.hasNSApplicationMain { stop = true }
        }

        if signals.declaresLibraryOnly && signals.declaresExecutable {
            signals.declaresLibraryOnly = false
        }
        return signals
    }

    // MARK: - Audio Unit detection

    private enum AudioUnitType { case instrument, effect, generic }

    private func detectAudioUnitType(at rootURL: URL) -> AudioUnitType? {
        var result: AudioUnitType?
        walk(rootURL) { url, stop in
            var plistData: Data?
            if url.pathExtension == "appex" {
                plistData = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
            } else if url.lastPathComponent == "Info.plist" {
                plistData = try? Data(contentsOf: url)
            }
            guard let data = plistData, let type = audioComponentType(in: data) else { return }
            result = type
            stop = true
        }
        return result
    }

    private func audioComponentType(in data: Data) -> AudioUnitType? {
        // Structured read first.
        if let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = object as? [String: Any] {
            guard let components = dict["AudioComponents"] as? [[String: Any]] else { return nil }
            for component in components {
                if let typeCode = component["type"] as? String {
                    return classifyAUType(typeCode)
                }
            }
            return .generic
        }
        // Text fallback (source/XML plists).
        if let text = String(data: data, encoding: .utf8), text.contains("AudioComponents") {
            if text.contains("aumu") || text.contains("aumi") || text.contains("auim") { return .instrument }
            if text.contains("aufx") || text.contains("aufc") { return .effect }
            return .generic
        }
        return nil
    }

    private func classifyAUType(_ code: String) -> AudioUnitType {
        switch code {
        case "aumu", "aumi", "auim": .instrument
        case "aufx", "aufc": .effect
        default: .generic
        }
    }

    // MARK: - Marker collection

    private func collectMarkers(at rootURL: URL) -> Set<String> {
        let interesting: Set<String> = [
            "Package.swift", "package.json", "Cargo.toml", "go.mod",
            "requirements.txt", "pyproject.toml", "setup.py", "Pipfile", "Podfile"
        ]
        var found: Set<String> = []
        walk(rootURL) { url, _ in
            let name = url.lastPathComponent
            if interesting.contains(name) { found.insert(name) }
            if url.pathExtension == "xcodeproj" || url.pathExtension == "xcworkspace" {
                found.insert(name)
            }
        }
        return found
    }

    // MARK: - Helpers

    private func readBoundedText(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: Self.maxSourceBytes)) ?? Data()
        return String(data: data, encoding: .utf8)
    }

    /// Depth- and entry-bounded recursive walk. Calls `visit` for every entry;
    /// set `stop` to true to end early.
    private func walk(_ root: URL, visit: (_ url: URL, _ stop: inout Bool) -> Void) {
        var visited = 0
        var stop = false

        func recurse(_ directory: URL, depth: Int) {
            guard !stop, depth <= Self.maxDepth, visited < Self.maxEntries else { return }
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for entry in entries {
                guard !stop, visited < Self.maxEntries else { return }
                visited += 1
                visit(entry, &stop)
                if stop { return }

                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let isBundle = ["xcodeproj", "xcworkspace", "appex", "app", "framework", "bundle"].contains(entry.pathExtension)
                if isDirectory, !isBundle, !Self.ignoredDirectories.contains(entry.lastPathComponent) {
                    recurse(entry, depth: depth + 1)
                }
            }
        }

        recurse(root, depth: 0)
    }
}
