import Foundation

/// What kind of software a project root actually contains.
/// Detected read-only from marker files on disk. This is the V1 foundation of
/// the ApplicabilityEngine: it lets LocalForge say "this is an AUv3 plugin" or
/// "this is a Swift package" instead of only showing a folder name.
public enum ProjectKind: String, Codable, CaseIterable, Sendable {
    case swiftUIApp = "SwiftUI App"
    case appKitApp = "AppKit App"
    case uiKitApp = "UIKit App"
    case audioUnitInstrument = "AUv3 Instrument"
    case audioUnitEffect = "AUv3 Effect"
    case audioUnitPlugin = "Audio Unit Plugin"
    case framework = "Framework"
    case commandLineTool = "Command-Line Tool"
    case xcodeApp = "Xcode Project"
    case swiftPackage = "Swift Package"
    case nodeWeb = "Node / Web"
    case pythonProject = "Python Project"
    case rustProject = "Rust Project"
    case goProject = "Go Project"
    case unidentified = "Unidentified"

    /// Whether this kind is an Audio Unit plugin of some sort.
    public var isAudioUnit: Bool {
        self == .audioUnitInstrument || self == .audioUnitEffect || self == .audioUnitPlugin
    }

    /// Whether this kind is a user-facing application.
    public var isApplication: Bool {
        self == .swiftUIApp || self == .appKitApp || self == .uiKitApp || self == .xcodeApp
    }

    /// SF Symbol name. Kept as a string so LocalForgeCore stays UI-framework free.
    public var symbolName: String {
        switch self {
        case .swiftUIApp: "macwindow"
        case .appKitApp: "macwindow.on.rectangle"
        case .uiKitApp: "iphone"
        case .audioUnitInstrument: "pianokeys"
        case .audioUnitEffect: "dial.medium"
        case .audioUnitPlugin: "waveform"
        case .framework: "building.columns"
        case .commandLineTool: "terminal"
        case .xcodeApp: "app.dashed"
        case .swiftPackage: "shippingbox"
        case .nodeWeb: "globe"
        case .pythonProject: "chevron.left.forwardslash.chevron.right"
        case .rustProject: "gearshape.2"
        case .goProject: "g.circle"
        case .unidentified: "questionmark.folder"
        }
    }

    /// Short label for tight UI (tabs, sidebar).
    public var shortLabel: String {
        switch self {
        case .swiftUIApp: "SwiftUI"
        case .appKitApp: "AppKit"
        case .uiKitApp: "UIKit"
        case .audioUnitInstrument: "AU Instr"
        case .audioUnitEffect: "AU FX"
        case .audioUnitPlugin: "AUv3"
        case .framework: "Framework"
        case .commandLineTool: "CLI"
        case .xcodeApp: "Xcode"
        case .swiftPackage: "SwiftPM"
        case .nodeWeb: "Node"
        case .pythonProject: "Python"
        case .rustProject: "Rust"
        case .goProject: "Go"
        case .unidentified: "Unknown"
        }
    }
}

public struct ProjectIdentity: Codable, Hashable, Sendable {
    public var kind: ProjectKind
    public var detail: String
    public var ecosystems: [String]
    public var markers: [String]
    public var confidence: EvidenceClassification

    public init(
        kind: ProjectKind,
        detail: String,
        ecosystems: [String] = [],
        markers: [String] = [],
        confidence: EvidenceClassification
    ) {
        self.kind = kind
        self.detail = detail
        self.ecosystems = ecosystems
        self.markers = markers
        self.confidence = confidence
    }

    public static let unknown = ProjectIdentity(
        kind: .unidentified,
        detail: "Project type has not been determined.",
        confidence: .unknown
    )
}
