import Foundation

/// Infers what a project is *trying to be* from its type, name, and README.
/// Read-only and deliberately low-confidence: this is a starting guess the user
/// can later confirm, not ground truth.
public struct MissionProfileEngine: Sendable {
    public init() {}

    public func profile(identity: ProjectIdentity, rootURL: URL, projectName: String) -> MissionProfile {
        let readme = readReadme(at: rootURL)
        let haystack = "\(projectName) \(readme)".lowercased()

        switch identity.kind {
        case .audioUnitInstrument:
            let descriptor = keyword(in: haystack, ["synth", "synthesizer", "sampler", "piano", "drum", "bass", "organ"]) ?? "instrument"
            return MissionProfile(
                category: .instrument,
                statedMission: "Audio Unit \(descriptor)",
                rationale: "Derived from AUv3 instrument type and project name/README keywords.",
                confidence: readme.isEmpty ? .assumed : .inferred
            )
        case .audioUnitEffect:
            let descriptor = keyword(in: haystack, ["reverb", "delay", "eq", "compressor", "distortion", "chorus", "filter"]) ?? "effect"
            return MissionProfile(
                category: .audioEffect,
                statedMission: "Audio Unit \(descriptor)",
                rationale: "Derived from AUv3 effect type and project name/README keywords.",
                confidence: readme.isEmpty ? .assumed : .inferred
            )
        case .audioUnitPlugin:
            return MissionProfile(category: .audioEffect, statedMission: "Audio Unit plugin", rationale: "Derived from Audio Unit markers.", confidence: .assumed)
        case .swiftUIApp, .appKitApp, .uiKitApp, .xcodeApp:
            return MissionProfile(
                category: .application,
                statedMission: missionFromReadme(haystack) ?? "\(identity.kind.rawValue)",
                rationale: readme.isEmpty ? "Derived from project type; no README summary found." : "Derived from project type and README.",
                confidence: readme.isEmpty ? .assumed : .inferred
            )
        case .commandLineTool:
            return MissionProfile(category: .developerTool, statedMission: "Command-line developer tool", rationale: "Derived from executable target with no UI.", confidence: .inferred)
        case .framework:
            return MissionProfile(category: .framework, statedMission: "Reusable framework", rationale: "Derived from framework product type.", confidence: .inferred)
        case .swiftPackage:
            return MissionProfile(category: .library, statedMission: "Swift library / package", rationale: "Derived from Swift package manifest.", confidence: .inferred)
        case .nodeWeb:
            return MissionProfile(category: .web, statedMission: "Node / web project", rationale: "Derived from package.json.", confidence: .inferred)
        case .pythonProject, .rustProject, .goProject:
            return MissionProfile(category: .developerTool, statedMission: "\(identity.kind.rawValue)", rationale: "Derived from ecosystem markers.", confidence: .assumed)
        case .unidentified:
            return .unknown
        }
    }

    private func missionFromReadme(_ haystack: String) -> String? {
        for (needle, mission) in [
            ("career", "Career management app"),
            ("sample library", "Sample library manager"),
            ("resume", "Resume / application manager"),
            ("note", "Notes application"),
            ("budget", "Budgeting application"),
            ("task", "Task management app")
        ] where haystack.contains(needle) {
            return mission
        }
        return nil
    }

    private func keyword(in haystack: String, _ options: [String]) -> String? {
        options.first { haystack.contains($0) }
    }

    private func readReadme(at rootURL: URL) -> String {
        let candidates = ["README.md", "README.markdown", "README.txt", "README"]
        for name in candidates {
            let url = rootURL.appendingPathComponent(name)
            if let handle = try? FileHandle(forReadingFrom: url) {
                defer { try? handle.close() }
                let data = (try? handle.read(upToCount: 8 * 1_024)) ?? Data()
                if let text = String(data: data, encoding: .utf8) { return text }
            }
        }
        return ""
    }
}
