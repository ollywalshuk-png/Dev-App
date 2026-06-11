import Foundation

/// Phase 7: a starter mission for a freshly-opened project. Pre-fills the
/// Setup Wizard with a sensible mission line, category, and phase so the
/// user only has to confirm.
public struct MissionTemplate: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var blurb: String
    public var category: MissionCategory
    public var statedMission: String
    public var defaultPhase: String
    public var defaultGoals: [String]
    public var packName: String?

    public init(
        name: String,
        blurb: String,
        category: MissionCategory,
        statedMission: String,
        defaultPhase: String,
        defaultGoals: [String],
        packName: String? = nil
    ) {
        self.name = name
        self.blurb = blurb
        self.category = category
        self.statedMission = statedMission
        self.defaultPhase = defaultPhase
        self.defaultGoals = defaultGoals
        self.packName = packName
    }
}

/// Phase 7: a Verification Pack — a curated list of verification areas (with
/// dependencies pre-wired) for a particular project kind. One click seeds the
/// project; the user can prune later.
public struct VerificationPackArea: Hashable, Sendable {
    public var area: String
    public var dependsOn: [String]
    public init(area: String, dependsOn: [String] = []) {
        self.area = area
        self.dependsOn = dependsOn
    }
}

/// Phase 8: a risk every project of this kind predictably faces. Applying a
/// pack offers these as pre-seeded Risk Register entries (skipping duplicates).
public struct RiskSeed: Hashable, Sendable {
    public var title: String
    public var description: String
    public var likelihood: RiskLikelihood
    public var impact: RiskImpact
    public var mitigation: String

    public init(
        title: String,
        description: String = "",
        likelihood: RiskLikelihood = .medium,
        impact: RiskImpact = .high,
        mitigation: String = ""
    ) {
        self.title = title
        self.description = description
        self.likelihood = likelihood
        self.impact = impact
        self.mitigation = mitigation
    }

    public func materialise() -> RiskRecord {
        RiskRecord(
            title: title,
            description: description,
            likelihood: likelihood,
            impact: impact,
            status: .open,
            mitigation: mitigation
        )
    }
}

public struct VerificationPack: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var blurb: String
    public var areas: [VerificationPackArea]
    /// Phase 8: kind-typical risks, offered when the pack is applied.
    public var suggestedRisks: [RiskSeed]

    public init(name: String, blurb: String, areas: [VerificationPackArea], suggestedRisks: [RiskSeed] = []) {
        self.name = name
        self.blurb = blurb
        self.areas = areas
        self.suggestedRisks = suggestedRisks
    }

    /// Materialise into seed verification records — all `.unknown`, with the
    /// pack's dependency wiring already in place.
    public func seedRecords(author: String = "") -> [VerificationRecord] {
        areas.map {
            VerificationRecord(
                area: $0.area,
                state: .unknown,
                note: "",
                verifiedBy: author,
                dependsOn: $0.dependsOn
            )
        }
    }
}

/// Looks up the templates / packs that fit a given project kind. Pure data;
/// no I/O.
public struct MissionTemplateCatalogue: Sendable {
    public init() {}

    public func templates(for kind: ProjectKind) -> [MissionTemplate] {
        switch kind {
        case .audioUnitInstrument:
            return [
                MissionTemplate(
                    name: "AUv3 Synth",
                    blurb: "AUv3 instrument with DSP, MIDI, preset system, AU validation.",
                    category: .instrument,
                    statedMission: "AUv3 software synthesizer",
                    defaultPhase: "DSP & UI",
                    defaultGoals: ["DSP solid", "MIDI complete", "Presets reliable", "Passes AU validation", "Polished UI"],
                    packName: "AUv3 Instrument Pack"
                ),
                MissionTemplate(
                    name: "AUv3 Sampler",
                    blurb: "Sample-based instrument; treat preset/state I/O as critical.",
                    category: .instrument,
                    statedMission: "AUv3 sample-based instrument",
                    defaultPhase: "Sample engine",
                    defaultGoals: ["Sample loading", "MIDI mapping", "Presets reliable", "AU validation"],
                    packName: "AUv3 Instrument Pack"
                ),
                MissionTemplate(
                    name: "AUv3 MIDI Processor",
                    blurb: "MIDI-in / MIDI-out processor — routing, transformation, host sync.",
                    category: .instrument,
                    statedMission: "AUv3 MIDI processor",
                    defaultPhase: "MIDI engine",
                    defaultGoals: ["MIDI routing correct", "Host tempo sync", "Presets reliable", "AU validation"],
                    packName: "MIDI Tool Pack"
                )
            ]
        case .audioUnitEffect, .audioUnitPlugin:
            return [
                MissionTemplate(
                    name: "AUv3 Effect",
                    blurb: "AUv3 effect: DSP-first, preset system, AU validation, no MIDI required.",
                    category: .audioEffect,
                    statedMission: "AUv3 audio effect",
                    defaultPhase: "DSP",
                    defaultGoals: ["DSP correctness", "Presets reliable", "Passes AU validation", "Polished UI"],
                    packName: "AUv3 Effect Pack"
                ),
                MissionTemplate(
                    name: "AUv3 MIDI Processor",
                    blurb: "MIDI-in / MIDI-out processor — routing, transformation, host sync.",
                    category: .instrument,
                    statedMission: "AUv3 MIDI processor",
                    defaultPhase: "MIDI engine",
                    defaultGoals: ["MIDI routing correct", "Host tempo sync", "Presets reliable", "AU validation"],
                    packName: "MIDI Tool Pack"
                )
            ]
        case .swiftUIApp, .appKitApp, .uiKitApp, .xcodeApp:
            return [
                MissionTemplate(
                    name: "macOS App",
                    blurb: "Document-style or utility macOS application.",
                    category: .application,
                    statedMission: "macOS application",
                    defaultPhase: "Feature build",
                    defaultGoals: ["Core feature working", "Persistence reliable", "Polished UI", "Signed & notarised"],
                    packName: "macOS App Pack"
                ),
                MissionTemplate(
                    name: "iOS App",
                    blurb: "iOS app with UIKit or SwiftUI.",
                    category: .application,
                    statedMission: "iOS application",
                    defaultPhase: "Feature build",
                    defaultGoals: ["Core feature working", "Persistence reliable", "Polished UI", "Signed for distribution"],
                    packName: "iOS App Pack"
                ),
                MissionTemplate(
                    name: "Developer Tool",
                    blurb: "Local-first tool for developers — repos, reports, safety model.",
                    category: .developerTool,
                    statedMission: "Developer productivity tool",
                    defaultPhase: "Core workflow",
                    defaultGoals: ["Project import reliable", "Reports accurate", "Safety model enforced", "Local storage solid"],
                    packName: "Developer Tool Pack"
                ),
                MissionTemplate(
                    name: "AV Utility",
                    blurb: "Audio-visual field utility — inventory, checks, fault logging, vendor handoff.",
                    category: .application,
                    statedMission: "AV management utility",
                    defaultPhase: "Field workflow",
                    defaultGoals: ["Device inventory", "Fault logging", "Report export", "Works fully offline"],
                    packName: "AV Utility Pack"
                ),
                MissionTemplate(
                    name: "Media App",
                    blurb: "Media library / playback app — import, organise, play, export.",
                    category: .application,
                    statedMission: "Media application",
                    defaultPhase: "Library & playback",
                    defaultGoals: ["Import reliable", "Playback solid", "Library persists", "Export works"],
                    packName: "Media App Pack"
                ),
                MissionTemplate(
                    name: "Automation Tool",
                    blurb: "Task automation — definitions, scheduling, recovery, logs.",
                    category: .script,
                    statedMission: "Automation tool",
                    defaultPhase: "Task engine",
                    defaultGoals: ["Tasks run reliably", "Failures recover", "Dry-run honest", "Logs complete"],
                    packName: "Automation Tool Pack"
                )
            ]
        case .commandLineTool:
            return [
                MissionTemplate(
                    name: "CLI Tool",
                    blurb: "Local command-line tool.",
                    category: .developerTool,
                    statedMission: "Developer command-line tool",
                    defaultPhase: "Build & tests",
                    defaultGoals: ["Argument parsing", "Tested", "Builds clean"],
                    packName: "CLI Tool Pack"
                ),
                MissionTemplate(
                    name: "Automation Tool",
                    blurb: "Task automation — definitions, scheduling, recovery, logs.",
                    category: .script,
                    statedMission: "Automation tool",
                    defaultPhase: "Task engine",
                    defaultGoals: ["Tasks run reliably", "Failures recover", "Dry-run honest", "Logs complete"],
                    packName: "Automation Tool Pack"
                )
            ]
        case .swiftPackage, .framework:
            return [
                MissionTemplate(
                    name: "Swift Library",
                    blurb: "Reusable Swift package or framework.",
                    category: .library,
                    statedMission: "Reusable Swift library",
                    defaultPhase: "API design",
                    defaultGoals: ["Public API stable", "Tests pass", "Documented"],
                    packName: "Framework Pack"
                )
            ]
        case .nodeWeb:
            return [MissionTemplate(name: "Node / Web", blurb: "Node-based service or web app.", category: .web, statedMission: "Web service", defaultPhase: "Feature build", defaultGoals: ["Routes working", "Tests pass"], packName: nil)]
        case .pythonProject:
            return [MissionTemplate(name: "Python Project", blurb: "Python application or script.", category: .script, statedMission: "Python project", defaultPhase: "Feature build", defaultGoals: ["Core script working", "Tests pass"], packName: nil)]
        case .rustProject:
            return [MissionTemplate(name: "Rust Project", blurb: "Rust application or library.", category: .developerTool, statedMission: "Rust project", defaultPhase: "Build & tests", defaultGoals: ["Builds clean", "Tests pass"], packName: nil)]
        case .goProject:
            return [MissionTemplate(name: "Go Project", blurb: "Go application or library.", category: .developerTool, statedMission: "Go project", defaultPhase: "Build & tests", defaultGoals: ["Builds clean", "Tests pass"], packName: nil)]
        case .unidentified:
            return []
        }
    }

    public func packs(for kind: ProjectKind) -> [VerificationPack] {
        switch kind {
        case .audioUnitInstrument:
            return [auv3InstrumentPack, midiToolPack]
        case .audioUnitEffect, .audioUnitPlugin:
            return [auv3EffectPack, midiToolPack]
        case .swiftUIApp, .appKitApp, .uiKitApp, .xcodeApp:
            return [macOSAppPack, iOSAppPack, developerToolPack, avUtilityPack, mediaAppPack, automationToolPack]
        case .commandLineTool:
            return [cliPack, automationToolPack]
        case .swiftPackage, .framework:
            return [frameworkPack]
        default:
            return []
        }
    }

    public func pack(named name: String) -> VerificationPack? {
        allPacks.first { $0.name == name }
    }

    public var allPacks: [VerificationPack] {
        [auv3InstrumentPack, auv3EffectPack, midiToolPack, macOSAppPack, iOSAppPack,
         developerToolPack, avUtilityPack, mediaAppPack, automationToolPack, cliPack, frameworkPack]
    }

    // MARK: - Pack definitions

    private var auv3InstrumentPack: VerificationPack {
        VerificationPack(
            name: "AUv3 Instrument Pack",
            blurb: "DSP, MIDI, presets, state restore, automation, host compatibility, AU validation.",
            areas: [
                VerificationPackArea(area: "DSP"),
                VerificationPackArea(area: "MIDI", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Audio I/O", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Parameter Tree"),
                VerificationPackArea(area: "Preset System", dependsOn: ["Parameter Tree"]),
                VerificationPackArea(area: "State Restore", dependsOn: ["Preset System", "Parameter Tree"]),
                VerificationPackArea(area: "Automation", dependsOn: ["Parameter Tree"]),
                VerificationPackArea(area: "Voice Management", dependsOn: ["DSP"]),
                VerificationPackArea(area: "CPU Safety", dependsOn: ["DSP"]),
                VerificationPackArea(area: "AU Validation", dependsOn: ["DSP", "Preset System", "Audio I/O", "State Restore"]),
                VerificationPackArea(area: "Host Compatibility", dependsOn: ["AU Validation"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Build"),
                VerificationPackArea(area: "Signing & Notarisation", dependsOn: ["Build"])
            ],
            suggestedRisks: [
                RiskSeed(title: "Preset corruption", description: "Presets lost or mangled across host restarts.", likelihood: .medium, impact: .high, mitigation: "Persistence tests in Logic + GarageBand; verify State Restore."),
                RiskSeed(title: "Host state restore failure", description: "AUState not restored identically by every host.", likelihood: .medium, impact: .critical, mitigation: "Restart-host round-trip test per host."),
                RiskSeed(title: "CPU overload under polyphony", description: "Voice count spikes starve the render thread.", likelihood: .medium, impact: .high, mitigation: "Profile at max polyphony; enforce voice cap.")
            ]
        )
    }

    private var auv3EffectPack: VerificationPack {
        VerificationPack(
            name: "AUv3 Effect Pack",
            blurb: "DSP, bypass, latency, wet/dry, automation, presets, AU validation.",
            areas: [
                VerificationPackArea(area: "DSP"),
                VerificationPackArea(area: "Audio I/O", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Bypass", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Wet/Dry Mix", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Latency Reporting", dependsOn: ["DSP"]),
                VerificationPackArea(area: "Parameter Tree"),
                VerificationPackArea(area: "Automation", dependsOn: ["Parameter Tree"]),
                VerificationPackArea(area: "Preset System", dependsOn: ["Parameter Tree"]),
                VerificationPackArea(area: "CPU Safety", dependsOn: ["DSP"]),
                VerificationPackArea(area: "AU Validation", dependsOn: ["DSP", "Preset System", "Audio I/O"]),
                VerificationPackArea(area: "Host Compatibility", dependsOn: ["AU Validation"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Build"),
                VerificationPackArea(area: "Signing & Notarisation", dependsOn: ["Build"])
            ],
            suggestedRisks: [
                RiskSeed(title: "Latency misreporting", description: "Host compensation breaks when reported latency is wrong.", likelihood: .medium, impact: .high, mitigation: "Null test against a delay-compensated reference."),
                RiskSeed(title: "Parameter zipper noise", description: "Audible stepping when parameters automate quickly.", likelihood: .medium, impact: .medium, mitigation: "Smooth parameter changes in the render block."),
                RiskSeed(title: "Preset corruption", description: "Presets lost or mangled across host restarts.", likelihood: .medium, impact: .high, mitigation: "Persistence tests in the host; verify state round-trip.")
            ]
        )
    }

    private var midiToolPack: VerificationPack {
        VerificationPack(
            name: "MIDI Tool Pack",
            blurb: "MIDI routing, transformation, timing, host sync, AU validation.",
            areas: [
                VerificationPackArea(area: "MIDI Input"),
                VerificationPackArea(area: "MIDI Output", dependsOn: ["MIDI Input"]),
                VerificationPackArea(area: "MIDI Transformation", dependsOn: ["MIDI Input"]),
                VerificationPackArea(area: "Timing & Host Sync", dependsOn: ["MIDI Output"]),
                VerificationPackArea(area: "Preset System"),
                VerificationPackArea(area: "AU Validation", dependsOn: ["MIDI Input", "MIDI Output", "Preset System"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "Event timing drift", description: "Transformed events land off the host grid.", likelihood: .medium, impact: .high, mitigation: "Timestamp-preserving transforms; sync test at multiple tempos."),
                RiskSeed(title: "Stuck notes", description: "Note-offs dropped during transformation or panic.", likelihood: .medium, impact: .high, mitigation: "All-notes-off audit; paired on/off invariants.")
            ]
        )
    }

    private var macOSAppPack: VerificationPack {
        VerificationPack(
            name: "macOS App Pack",
            blurb: "UI, navigation, persistence, import/export, accessibility, error handling, signing.",
            areas: [
                VerificationPackArea(area: "Launch"),
                VerificationPackArea(area: "Navigation", dependsOn: ["Launch"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Persistence"),
                VerificationPackArea(area: "Settings", dependsOn: ["Persistence"]),
                VerificationPackArea(area: "Import"),
                VerificationPackArea(area: "Export"),
                VerificationPackArea(area: "Error Handling"),
                VerificationPackArea(area: "Accessibility"),
                VerificationPackArea(area: "Dark Mode"),
                VerificationPackArea(area: "Window State", dependsOn: ["Persistence"]),
                VerificationPackArea(area: "App Sandbox"),
                VerificationPackArea(area: "Document Workflow"),
                VerificationPackArea(area: "Automated Tests"),
                VerificationPackArea(area: "Build"),
                VerificationPackArea(area: "Signing & Notarisation", dependsOn: ["Build"])
            ],
            suggestedRisks: [
                RiskSeed(title: "Data loss on crash", description: "Unsaved state lost if the app dies mid-save.", likelihood: .medium, impact: .critical, mitigation: "Atomic writes; crash-during-save test."),
                RiskSeed(title: "Sandbox permission regressions", description: "Entitlement changes silently break file access.", likelihood: .medium, impact: .high, mitigation: "Bookmark restore test after re-sign.")
            ]
        )
    }

    private var iOSAppPack: VerificationPack {
        VerificationPack(
            name: "iOS App Pack",
            blurb: "UI, navigation, persistence, background behaviour, accessibility, signing.",
            areas: [
                VerificationPackArea(area: "Launch"),
                VerificationPackArea(area: "Navigation", dependsOn: ["Launch"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Persistence"),
                VerificationPackArea(area: "Settings", dependsOn: ["Persistence"]),
                VerificationPackArea(area: "Background Behaviour"),
                VerificationPackArea(area: "Error Handling"),
                VerificationPackArea(area: "Accessibility"),
                VerificationPackArea(area: "Automated Tests"),
                VerificationPackArea(area: "Build"),
                VerificationPackArea(area: "Signing & Notarisation", dependsOn: ["Build"])
            ],
            suggestedRisks: [
                RiskSeed(title: "Data loss on background kill", description: "State not persisted before iOS terminates the app.", likelihood: .medium, impact: .critical, mitigation: "Persist on scene-phase change; relaunch test."),
                RiskSeed(title: "App Review rejection", description: "Guideline violations discovered at submission.", likelihood: .low, impact: .high, mitigation: "Pre-submission checklist against current guidelines.")
            ]
        )
    }

    private var developerToolPack: VerificationPack {
        VerificationPack(
            name: "Developer Tool Pack",
            blurb: "Project import, file access, reports, safety model, redaction, local storage.",
            areas: [
                VerificationPackArea(area: "Project Import"),
                VerificationPackArea(area: "File Access", dependsOn: ["Project Import"]),
                VerificationPackArea(area: "Bookmark Persistence", dependsOn: ["File Access"]),
                VerificationPackArea(area: "Report Generation"),
                VerificationPackArea(area: "Redaction", dependsOn: ["Report Generation"]),
                VerificationPackArea(area: "Command Safety"),
                VerificationPackArea(area: "Handoff Generation", dependsOn: ["Report Generation"]),
                VerificationPackArea(area: "Local Storage"),
                VerificationPackArea(area: "Automated Tests"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "Secret leakage in reports", description: "Credentials or private paths escape via generated output.", likelihood: .medium, impact: .critical, mitigation: "Redaction tests on every report artefact."),
                RiskSeed(title: "Stale bookmark lockout", description: "Saved repo access breaks after moves/renames.", likelihood: .medium, impact: .medium, mitigation: "Stale-bookmark recovery flow with a visible re-open path.")
            ]
        )
    }

    private var avUtilityPack: VerificationPack {
        VerificationPack(
            name: "AV Utility Pack",
            blurb: "Device inventory, room checks, fault logging, report export, offline operation.",
            areas: [
                VerificationPackArea(area: "Device Inventory"),
                VerificationPackArea(area: "Room Checks", dependsOn: ["Device Inventory"]),
                VerificationPackArea(area: "Fault Logging"),
                VerificationPackArea(area: "Evidence Capture", dependsOn: ["Fault Logging"]),
                VerificationPackArea(area: "Report Export", dependsOn: ["Fault Logging"]),
                VerificationPackArea(area: "Vendor Handoff", dependsOn: ["Report Export"]),
                VerificationPackArea(area: "Search"),
                VerificationPackArea(area: "Offline Operation"),
                VerificationPackArea(area: "Permissions"),
                VerificationPackArea(area: "Local Storage"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "Data loss in the field", description: "Inventory edits lost without connectivity.", likelihood: .medium, impact: .high, mitigation: "Local-first writes; offline round-trip test."),
                RiskSeed(title: "Report rejected by vendor", description: "Export format doesn't match vendor requirements.", likelihood: .medium, impact: .medium, mitigation: "Vendor-format fixture tests.")
            ]
        )
    }

    private var mediaAppPack: VerificationPack {
        VerificationPack(
            name: "Media App Pack",
            blurb: "Import, playback, library persistence, metadata, export.",
            areas: [
                VerificationPackArea(area: "Media Import"),
                VerificationPackArea(area: "Metadata", dependsOn: ["Media Import"]),
                VerificationPackArea(area: "Library Persistence", dependsOn: ["Media Import"]),
                VerificationPackArea(area: "Playback", dependsOn: ["Media Import"]),
                VerificationPackArea(area: "Search", dependsOn: ["Metadata"]),
                VerificationPackArea(area: "Export", dependsOn: ["Library Persistence"]),
                VerificationPackArea(area: "User Interface"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "Library corruption", description: "Index diverges from files on disk.", likelihood: .medium, impact: .high, mitigation: "Rebuild-from-disk recovery; consistency check on launch."),
                RiskSeed(title: "Unsupported media formats", description: "Imports silently fail for edge-case codecs.", likelihood: .high, impact: .medium, mitigation: "Format matrix test; explicit unsupported-format errors.")
            ]
        )
    }

    private var automationToolPack: VerificationPack {
        VerificationPack(
            name: "Automation Tool Pack",
            blurb: "Task definitions, scheduling, error recovery, dry-run, logging.",
            areas: [
                VerificationPackArea(area: "Task Definitions"),
                VerificationPackArea(area: "Scheduling", dependsOn: ["Task Definitions"]),
                VerificationPackArea(area: "Dry-Run Mode", dependsOn: ["Task Definitions"]),
                VerificationPackArea(area: "Error Recovery", dependsOn: ["Scheduling"]),
                VerificationPackArea(area: "Logging"),
                VerificationPackArea(area: "Automated Tests"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "Silent task failure", description: "A scheduled task fails without anyone noticing.", likelihood: .medium, impact: .high, mitigation: "Failure surfacing + retry policy; alert on consecutive failures."),
                RiskSeed(title: "Destructive run without dry-run", description: "A bad definition mutates real data on first run.", likelihood: .low, impact: .critical, mitigation: "Dry-run default for new tasks.")
            ]
        )
    }

    private var cliPack: VerificationPack {
        VerificationPack(
            name: "CLI Tool Pack",
            blurb: "Argument parsing, exit codes, error output, build, tests.",
            areas: [
                VerificationPackArea(area: "Argument Parsing"),
                VerificationPackArea(area: "Exit Codes", dependsOn: ["Argument Parsing"]),
                VerificationPackArea(area: "Error Output"),
                VerificationPackArea(area: "Build"),
                VerificationPackArea(area: "Automated Tests", dependsOn: ["Build"]),
                VerificationPackArea(area: "Persistence")
            ],
            suggestedRisks: [
                RiskSeed(title: "Breaking flag changes", description: "Renamed flags break existing scripts.", likelihood: .medium, impact: .medium, mitigation: "Deprecation aliases; flag-compat tests.")
            ]
        )
    }

    private var frameworkPack: VerificationPack {
        VerificationPack(
            name: "Framework Pack",
            blurb: "API stability, semantic versioning, docs, tests, build.",
            areas: [
                VerificationPackArea(area: "API Stability"),
                VerificationPackArea(area: "Semantic Versioning", dependsOn: ["API Stability"]),
                VerificationPackArea(area: "Documentation"),
                VerificationPackArea(area: "Automated Tests"),
                VerificationPackArea(area: "Build")
            ],
            suggestedRisks: [
                RiskSeed(title: "API breakage downstream", description: "A signature change breaks dependents at their next update.", likelihood: .medium, impact: .high, mitigation: "API-diff check before tagging releases.")
            ]
        )
    }
}
