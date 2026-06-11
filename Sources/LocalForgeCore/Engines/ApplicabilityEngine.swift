import Foundation

/// Decides which checks are in scope for a given project. This is what stops
/// LocalForge from flagging "AU validation missing" on a document app, or
/// "document workflow missing" on a synthesizer.
public struct ApplicabilityEngine: Sendable {
    public init() {}

    /// Canonical areas LocalForge reasons about.
    public enum Area: String, CaseIterable {
        case dsp = "DSP"
        case midi = "MIDI"
        case presetSystem = "Preset System"
        case auValidation = "AU Validation"
        case audioIO = "Audio I/O"
        case ui = "User Interface"
        case persistence = "Persistence"
        case documentWorkflow = "Document Workflow"
        case build = "Build"
        case signing = "Signing & Notarisation"
        case tests = "Automated Tests"
        case apiStability = "API Stability"
    }

    public func items(for identity: ProjectIdentity, mission: MissionProfile) -> [ApplicabilityItem] {
        var map: [Area: ApplicabilityStatus] = [:]

        // Defaults: most areas unknown until proven applicable.
        for area in Area.allCases { map[area] = .notApplicable }
        map[.build] = .required
        map[.tests] = .expected

        switch identity.kind {
        case .audioUnitInstrument:
            map[.dsp] = .required
            map[.midi] = .required
            map[.presetSystem] = .expected
            map[.auValidation] = .required
            map[.audioIO] = .required
            map[.ui] = .expected
            map[.signing] = .expected
        case .audioUnitEffect, .audioUnitPlugin:
            map[.dsp] = .required
            map[.midi] = .optional
            map[.presetSystem] = .expected
            map[.auValidation] = .required
            map[.audioIO] = .required
            map[.ui] = .expected
            map[.signing] = .expected
        case .swiftUIApp, .appKitApp, .uiKitApp, .xcodeApp:
            map[.ui] = .required
            map[.persistence] = .expected
            map[.documentWorkflow] = .optional
            map[.signing] = .expected
        case .commandLineTool:
            map[.ui] = .notApplicable
            map[.persistence] = .optional
        case .framework, .swiftPackage:
            map[.apiStability] = .expected
            map[.tests] = .required
            map[.ui] = .notApplicable
        case .nodeWeb, .pythonProject, .rustProject, .goProject:
            map[.ui] = .optional
            map[.persistence] = .optional
            map[.signing] = .notApplicable
        case .unidentified:
            for area in Area.allCases { map[area] = .unknown }
        }

        // Stable, readable ordering: in-scope first, then optional, then N/A.
        return Area.allCases
            .map { area in
                let status = map[area] ?? .unknown
                return ApplicabilityItem(
                    area: area.rawValue,
                    status: status,
                    priority: priority(for: area, status: status, kind: identity.kind)
                )
            }
            .sorted { lhs, rhs in
                if rank(lhs.status) != rank(rhs.status) { return rank(lhs.status) < rank(rhs.status) }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.area < rhs.area
            }
    }

    /// Phase 6: priority weighting per area.
    /// Release blockers (Build/AU Validation/DSP/Signing/Persistence/Preset/Audio I/O) are
    /// Critical for projects where they apply; UI is High; documents/optional surfaces are Medium;
    /// API stability is High for libraries; Tests are High; tests are Medium for apps.
    private func priority(for area: Area, status: ApplicabilityStatus, kind: ProjectKind) -> VerificationPriority {
        guard status.inScope else { return .low }
        switch area {
        case .build, .signing:
            return .critical
        case .auValidation, .audioIO, .dsp, .presetSystem:
            return kind.isAudioUnit ? .critical : .high
        case .midi:
            return kind == .audioUnitInstrument ? .critical : .high
        case .ui:
            return kind.isApplication ? .high : .medium
        case .persistence:
            return kind.isApplication ? .high : .medium
        case .tests:
            return (kind == .swiftPackage || kind == .framework) ? .high : .medium
        case .apiStability:
            return .high
        case .documentWorkflow:
            return .medium
        }
    }

    private func rank(_ status: ApplicabilityStatus) -> Int {
        switch status {
        case .required: 0
        case .expected: 1
        case .optional: 2
        case .unknown: 3
        case .notApplicable: 4
        }
    }
}
