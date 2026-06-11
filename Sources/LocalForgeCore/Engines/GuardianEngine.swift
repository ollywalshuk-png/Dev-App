import Foundation

/// Picks the single most useful thing for the developer to see right now and
/// describes it as Top Issue · Status · Evidence · Impact · Suggested Action.
/// Driven by real verification records, known issues, and findings — not heuristics.
public struct GuardianEngine: Sendable {
    public init() {}

    /// Phase 6.5: enrich the top issue with journal activity, blockers from
    /// verification dependencies, and linked counts. Pure overload — the simple
    /// form still works.
    public func recommendation(
        for snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote] = [],
        journal: [JournalEntry] = [],
        evidence: [EvidenceRecord] = []
    ) -> GuardianRecommendation {
        var rec = recommendation(for: snapshot)
        guard !rec.area.isEmpty else { return rec }

        let area = rec.area
        let stateByArea = Dictionary(uniqueKeysWithValues: snapshot.verification.map { ($0.area, $0.state) })
        if let record = snapshot.verification.first(where: { $0.area == area }) {
            rec.blockedBy = record.dependsOn.compactMap { dep in
                let s = stateByArea[dep] ?? .unknown
                return s == .verified ? nil : "\(dep) (\(s.rawValue))"
            }
        }

        let related = journal
            .filter { $0.summary.localizedCaseInsensitiveContains(area) || $0.detail.localizedCaseInsensitiveContains(area) }
            .sorted { $0.occurredAt > $1.occurredAt }
        rec.linkedJournalCount = related.count
        rec.recentActivity = related.prefix(3).map { entry in
            let date = entry.occurredAt.formatted(date: .abbreviated, time: .omitted)
            return "\(date) · \(entry.summary)"
        }

        rec.linkedNotesCount = knowledge.filter {
            $0.title.localizedCaseInsensitiveContains(area)
                || $0.body.localizedCaseInsensitiveContains(area)
        }.count

        rec.linkedEvidenceCount = evidence.filter { $0.area == area }.count

        return rec
    }

    public func recommendation(for snapshot: RepoSnapshot) -> GuardianRecommendation {
        let mode = snapshot.userMission == nil
            ? "Active Guidance"
            : "Mission Watch — \(snapshot.mission.statedMission)"

        // Phase 6: respect priority. Sort failures by area priority first, then by recency.
        let priorityByArea = Dictionary(uniqueKeysWithValues: snapshot.applicability.map { ($0.area, $0.priority) })

        // 1) Highest-priority signal: a failed verification record.
        if let failing = snapshot.verification
            .filter({ $0.state == .failed })
            .sorted(by: { lhs, rhs in
                let lp = priorityByArea[lhs.area] ?? .medium
                let rp = priorityByArea[rhs.area] ?? .medium
                if lp != rp { return lp < rp } // lower rank = higher priority
                return lhs.updatedAt > rhs.updatedAt
            })
            .first {
            let priority = priorityByArea[failing.area] ?? .medium
            let impact = impactStatement(for: failing.area, snapshot: snapshot, priority: priority)
            return GuardianRecommendation(
                mode: mode,
                riskLevel: priority == .critical ? .critical : .warning,
                topIssue: failing.area,
                evidence: failing.note.isEmpty ? "User-reported failure with no detail captured." : failing.note,
                confidence: .observed,
                nextAction: suggestedFix(for: failing.area, note: failing.note),
                area: failing.area,
                status: "Failed",
                impact: impact,
                suggestedAction: suggestedFix(for: failing.area, note: failing.note),
                verifiedBy: failing.verifiedBy,
                lastObservedAt: failing.updatedAt,
                estimatedEffortMinutes: estimatedEffort(for: failing.area),
                priority: priority
            )
        }

        // 1b) An expired or stale Verified record is a real risk that needs re-verification.
        let stalest = snapshot.verification
            .filter { $0.state == .verified && ($0.age == .stale || $0.age == .expired) }
            .sorted { (priorityByArea[$0.area] ?? .medium) < (priorityByArea[$1.area] ?? .medium) }
            .first
        if let stale = stalest {
            let priority = priorityByArea[stale.area] ?? .medium
            return GuardianRecommendation(
                mode: mode,
                riskLevel: priority == .critical ? .warning : .info,
                topIssue: "\(stale.area) verification is \(stale.age.rawValue.lowercased())",
                evidence: "Last verified \(stale.ageDescription). Trust has decayed; re-verification recommended.",
                confidence: .inferred,
                nextAction: "Re-verify \(stale.area) and update the record.",
                area: stale.area,
                status: stale.age.rawValue,
                impact: "Reality is partially counting this area; full credit only returns when re-verified.",
                suggestedAction: suggestedFix(for: stale.area, note: ""),
                verifiedBy: stale.verifiedBy,
                lastObservedAt: stale.updatedAt,
                estimatedEffortMinutes: estimatedEffort(for: stale.area),
                priority: priority
            )
        }

        // 2) A known issue written into the Knowledge Vault.
        if let knownIssue = snapshot.reality.topRisks.first(where: { $0.lowercased().contains("known issue") }) {
            let cleaned = knownIssue.replacingOccurrences(of: "Known issue: ", with: "")
            return GuardianRecommendation(
                mode: mode,
                riskLevel: .warning,
                topIssue: cleaned,
                evidence: "Recorded in Knowledge Vault as a known issue.",
                confidence: .observed,
                nextAction: "Investigate the known issue and turn it into a verification record once resolved.",
                area: "Known Issues",
                status: "Open",
                impact: "May block release until cleared.",
                suggestedAction: "Capture reproduction steps; add a Verification record for the affected area.",
                verifiedBy: ""
            )
        }

        // 3) Required in-scope area without verification evidence yet.
        let verifiedAreas = Set(snapshot.verification.filter { $0.state == .verified }.map(\.area))
        if let required = snapshot.applicability.first(where: { $0.status == .required && !verifiedAreas.contains($0.area) }) {
            return GuardianRecommendation(
                mode: mode,
                riskLevel: .warning,
                topIssue: required.area,
                evidence: "Required for a \(snapshot.identity.kind.rawValue) but no verification evidence has been recorded.",
                confidence: .unknown,
                nextAction: suggestedFix(for: required.area, note: ""),
                area: required.area,
                status: "Unverified",
                impact: "Required area; project cannot be considered release-ready until verified.",
                suggestedAction: suggestedFix(for: required.area, note: ""),
                verifiedBy: ""
            )
        }

        // 4) Anything still in progress.
        if let inProgress = snapshot.verification.first(where: { $0.state == .inProgress }) {
            return GuardianRecommendation(
                mode: mode,
                riskLevel: .info,
                topIssue: inProgress.area,
                evidence: inProgress.note.isEmpty ? "Marked in-progress without a note." : inProgress.note,
                confidence: .inferred,
                nextAction: "Finish verifying \(inProgress.area) and record the result.",
                area: inProgress.area,
                status: "In Progress",
                impact: "Pending — Reality score is held back until this completes.",
                suggestedAction: "Complete the planned verification and update the record.",
                verifiedBy: inProgress.verifiedBy
            )
        }

        // 5) Healthy path.
        let nothingTracked = snapshot.verification.isEmpty
        return GuardianRecommendation(
            mode: mode,
            riskLevel: nothingTracked ? .unknown : .healthy,
            topIssue: nothingTracked ? "No verification records yet" : "All in-scope areas tracked",
            evidence: nothingTracked
                ? "Define the project mission and choose verification areas to start the workflow."
                : "Reality \(snapshot.reality.score)% · \(snapshot.verificationSummary.verified) verified · \(snapshot.verificationSummary.failed) failed.",
            confidence: nothingTracked ? .unknown : .observed,
            nextAction: nothingTracked
                ? "Open the Project Setup Wizard, or define a mission from the Workspace."
                : "Continue verifying and re-confirm older records periodically.",
            area: "Workspace",
            status: nothingTracked ? "Setup pending" : "On track",
            impact: nothingTracked ? "Without a mission the Reality score cannot reflect what actually matters." : "Sustain coverage; verification ages over time.",
            suggestedAction: nothingTracked ? "Define mission · choose verification areas · record evidence as you confirm." : "Re-verify the oldest records first.",
            verifiedBy: ""
        )
    }

    // MARK: - Helpers

    private func impactStatement(for area: String, snapshot: RepoSnapshot, priority: VerificationPriority) -> String {
        switch priority {
        case .critical:
            return "Release blocking — \(area) is a critical area for a \(snapshot.identity.kind.rawValue). Reality is heavily penalised until resolved."
        case .high:
            return "High impact — \(area) is in scope and weighted heavily in Reality."
        case .medium:
            return "Medium impact — \(area) failures lower the Reality score but are not release-blocking."
        case .low:
            return "Low impact — \(area) is tracked but not critical to ship."
        }
    }

    /// Phase 6: rough effort estimate per area. Honest guesses, not magic.
    private func estimatedEffort(for area: String) -> Int {
        switch area {
        case "AU Validation": 20
        case "Preset System": 30
        case "DSP": 45
        case "MIDI": 30
        case "Audio I/O": 20
        case "Persistence": 25
        case "User Interface": 60
        case "Build": 15
        case "Signing & Notarisation": 30
        case "Automated Tests": 20
        case "API Stability": 45
        default: 30
        }
    }

    private func suggestedFix(for area: String, note: String) -> String {
        let suggestions: [String: String] = [
            "AU Validation": "Run `auval -v <type> <subtype> <manufacturer>` against the built component; capture stdout and update the record.",
            "Preset System": "Save a preset in Logic, quit Logic, reopen the project, confirm parameter values restore exactly. Note the result.",
            "DSP": "Render a 60-second test signal at 44.1, 48, and 96 kHz; confirm no real-time-thread violations and no allocations on the audio thread.",
            "MIDI": "Send note-on/note-off across the full range and CC sweeps; check for stuck notes after burst input.",
            "Audio I/O": "Confirm the plugin produces audio at every supported sample rate and buffer size with no dropouts.",
            "Persistence": "Make a change, quit the app, relaunch, confirm the change survived. Note the storage path used.",
            "User Interface": "Walk every declared control once; confirm visibility, reach, and disabled-state behaviour.",
            "Build": "Run a clean build (`xcodebuild -scheme … -configuration Release`); record success/failure and any warnings.",
            "Signing & Notarisation": "Run `codesign --verify --deep --strict --verbose=2 <bundle>` and `spctl --assess --verbose=4`; record the result.",
            "Automated Tests": "Run the test suite (`swift test` or `xcodebuild test`) and record pass/fail counts.",
            "API Stability": "Diff the public API surface against the last release; record any intentional breaking changes."
        ]
        if let suggestion = suggestions[area] {
            return note.isEmpty ? suggestion : "\(suggestion) Existing note: \(note)"
        }
        return "Verify \(area) and record the outcome with evidence."
    }
}
