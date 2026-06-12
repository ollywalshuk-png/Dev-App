import Foundation

/// Turns the project's real state — identity, mission, applicability, verification,
/// knowledge notes, reality — into copyable artefacts the developer can hand to
/// Codex, Claude, ChatGPT, a teammate, or themselves later.
///
/// No external calls. Pure local synthesis from the snapshot.
public struct PromptForgeEngine: Sendable {
    public init() {}

    // MARK: - Public surface

    public enum Artefact: String, CaseIterable, Sendable {
        case codexPrompt = "Codex Prompt"
        case claudePrompt = "Claude Prompt"
        case fixProposal = "Fix Proposal"
        case comprehensiveHandoff = "Comprehensive Handoff"
        case reviewerBrief = "Reviewer Brief"

        public var symbolName: String {
            switch self {
            case .codexPrompt: "chevron.left.forwardslash.chevron.right"
            case .claudePrompt: "sparkle"
            case .fixProposal: "wrench.and.screwdriver"
            case .comprehensiveHandoff: "paperplane"
            case .reviewerBrief: "checkmark.shield"
            }
        }

        public var blurb: String {
            switch self {
            case .codexPrompt:
                "Self-contained brief for Codex/Cursor. Repo state, mission, top risk, constraints, requested action — read-only by default."
            case .claudePrompt:
                "Self-contained brief for Claude. Reality summary, what is in/out of scope, what not to touch, what to produce."
            case .fixProposal:
                "Markdown plan for the top risk: symptom, evidence, likely causes, safe diagnostic steps, verification plan, rollback."
            case .comprehensiveHandoff:
                "Full project pack: identity, mission, goals, phase, applicability, verification, reality, knowledge, evidence — every section copyable."
            case .reviewerBrief:
                "Short brief for a human reviewer or teammate — what changed, what's verified, what isn't, what to look at first."
            }
        }
    }

    public func generate(
        _ artefact: Artefact,
        snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote] = [],
        evidence: [EvidenceRecord] = [],
        risks: [RiskRecord] = [],
        decisions: [DecisionRecord] = [],
        architecture: [ArchitectureItem] = [],
        assumptions: [AssumptionRecord] = []
    ) -> String {
        switch artefact {
        case .codexPrompt:
            codexPrompt(
                snapshot: snapshot,
                knowledge: knowledge,
                evidence: evidence,
                risks: risks,
                assumptions: assumptions
            )
        case .claudePrompt:
            claudePrompt(
                snapshot: snapshot,
                knowledge: knowledge,
                evidence: evidence,
                risks: risks,
                assumptions: assumptions
            )
        case .fixProposal: fixProposal(snapshot: snapshot, knowledge: knowledge, evidence: evidence)
        case .comprehensiveHandoff: comprehensiveHandoff(
                snapshot: snapshot,
                knowledge: knowledge,
                evidence: evidence,
                risks: risks,
                decisions: decisions,
                architecture: architecture,
                assumptions: assumptions
            )
        case .reviewerBrief:
            reviewerBrief(
                snapshot: snapshot,
                evidence: evidence,
                risks: risks,
                assumptions: assumptions
            )
        }
    }

    /// The structured sections a handoff is built from. Useful for per-section
    /// copy buttons in the UI.
    public func handoffSections(
        snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote] = [],
        evidence: [EvidenceRecord] = [],
        risks: [RiskRecord] = [],
        decisions: [DecisionRecord] = [],
        architecture: [ArchitectureItem] = [],
        assumptions: [AssumptionRecord] = []
    ) -> [HandoffSection] {
        let r = snapshot.reality
        let s = snapshot.verificationSummary
        let mission = snapshot.userMission
        let goals = mission?.goals ?? []
        let issues = mission?.knownIssues ?? []
        let phase = mission?.currentPhase ?? ""

        var sections: [HandoffSection] = []

        sections.append(HandoffSection(title: "Project", body: """
        Name: \(snapshot.project.name)
        Root: \(snapshot.project.rootURL.path)
        Type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]
        Ecosystems: \(snapshot.identity.ecosystems.joined(separator: ", "))
        Permission: \(snapshot.permissionState.rawValue) · Read-only: \(snapshot.isReadOnly ? "yes" : "no")
        Scan mode: \(snapshot.scanPolicy.mode.rawValue) · Scanned: \(formatted(snapshot.scannedAt))
        """))

        sections.append(HandoffSection(title: "Mission", body: """
        Mission: \(snapshot.mission.statedMission) [\(snapshot.mission.confidence.rawValue)]
        Category: \(snapshot.mission.category.rawValue)
        Current phase: \(phase.isEmpty ? "—" : phase)
        Goals:
        \(bullets(goals))
        Known issues:
        \(bullets(issues))
        """))

        sections.append(HandoffSection(title: "Reality", body: """
        Reality score: \(r.score)%
        Current state: \(r.currentState)
        Verification: \(s.verified) verified · \(s.inProgress) in progress · \(s.failed) failed · \(s.unknown) unknown
        Top risks:
        \(bullets(r.topRisks))
        Unverified (in scope):
        \(bullets(r.unverified))
        Assumptions:
        \(bullets(r.assumptions))
        Unknowns:
        \(bullets(r.unknowns))
        Next action: \(r.nextAction)
        """))

        sections.append(truthDebtSection(for: truthDebtReport(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )))
        sections.append(releaseClaimGuardSection(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        ))

        sections.append(HandoffSection(title: "Applicability", body: snapshot.applicability
            .map { "- \($0.area): \($0.status.rawValue)" }
            .joined(separator: "\n")))

        sections.append(HandoffSection(title: "Verification", body: snapshot.verification.isEmpty
            ? "No verification records yet."
            : snapshot.verification
                .map { record in
                    let by = record.verifiedBy.isEmpty ? "unknown verifier" : record.verifiedBy
                    let note = record.note.isEmpty ? "" : " — \(record.note)"
                    return "- \(record.area): \(record.state.rawValue) (\(formatted(record.updatedAt)), \(by))\(note)"
                }
                .joined(separator: "\n")))

        sections.append(HandoffSection(title: "Git", body: gitBlock(snapshot.git)))

        sections.append(HandoffSection(title: "Repository", body: """
        Files: \(snapshot.summary.totalFiles)
        Source: \(snapshot.summary.sourceFiles)
        Tests: \(snapshot.summary.testFiles)
        Docs: \(snapshot.summary.documentationFiles)
        Large (>25 MB): \(snapshot.summary.largeFiles)
        """))

        if !evidence.isEmpty {
            let body = evidence.map { record -> String in
                let header = "[\(safeInline(record.area)) · \(record.kind.rawValue) · \(record.classification.rawValue)] \(safeInline(record.summary)) (\(formatted(record.createdAt)))"
                var lines = ["- \(header)"]
                if !record.body.isEmpty { lines.append("  \(safeBlock(record.body).replacingOccurrences(of: "\n", with: "\n  "))") }
                if !record.attachmentPath.isEmpty { lines.append("  Attachment: \(safeInline(record.attachmentPath))") }
                return lines.joined(separator: "\n")
            }.joined(separator: "\n")
            sections.append(HandoffSection(title: "Evidence", body: body))
        }

        if !knowledge.isEmpty {
            let body = knowledge.map { note -> String in
                let header = "[\(note.kind.rawValue)] \(safeInline(note.title)) (\(formatted(note.updatedAt)))"
                let author = note.author.isEmpty ? "" : "\nby \(safeInline(note.author))"
                return "- \(header)\(author)\n  \(safeBlock(note.body).replacingOccurrences(of: "\n", with: "\n  "))"
            }.joined(separator: "\n")
            sections.append(HandoffSection(title: "Knowledge Notes", body: body))
        }

        if !risks.isEmpty {
            sections.append(HandoffSection(title: "Risk Register", body: risks.map {
                "- [\($0.status.rawValue)] \(safeInline($0.title)) — \($0.impact.rawValue) impact, \($0.likelihood.rawValue) likelihood\($0.mitigation.isEmpty ? "" : " · mitigation: \(safeInline($0.mitigation))")"
            }.joined(separator: "\n")))
        }
        if !decisions.isEmpty {
            sections.append(HandoffSection(title: "Decision Register", body: decisions.map {
                "- [\($0.status.rawValue)] \(safeInline($0.title))\($0.reason.isEmpty ? "" : " — \(safeInline($0.reason))")"
            }.joined(separator: "\n")))
        }
        if !architecture.isEmpty {
            sections.append(HandoffSection(title: "Architecture", body: architecture.map {
                let deps = $0.dependencies.isEmpty ? "" : " · depends on: \($0.dependencies.map { safeInline($0) }.joined(separator: ", "))"
                return "- \(safeInline($0.name)) [\($0.subsystemType.rawValue) · \($0.status.rawValue)]\($0.purpose.isEmpty ? "" : " — \(safeInline($0.purpose))")\(deps)"
            }.joined(separator: "\n")))
        }
        if !assumptions.isEmpty {
            sections.append(HandoffSection(title: "Assumption Register", body: assumptions.map {
                "- [\($0.status.rawValue) · \($0.confidence.rawValue)] \(safeInline($0.assumption))\($0.verificationNeeded.isEmpty ? "" : " · verify by: \(safeInline($0.verificationNeeded))")"
            }.joined(separator: "\n")))
        }

        sections.append(HandoffSection(title: "Constraints", body: """
        - Read-only by default: do not modify the working tree without explicit approval.
        - Local-first: no telemetry, no cloud AI, no source upload, no paid APIs.
        - No destructive shell or mutating Git commands (LocalForge's CommandSafetyEngine blocks these).
        - Preserve mission and verification semantics; do not invent verified evidence.
        """))

        return sections
    }

    // MARK: - Artefact builders

    private func codexPrompt(
        snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote],
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> String {
        let r = snapshot.reality
        let mission = snapshot.userMission
        let topRisk = r.topRisks.first ?? "No verified top risk yet."
        let truthDebt = truthDebtReport(snapshot: snapshot, evidence: evidence, risks: risks, assumptions: assumptions)
        let text = """
        # Codex Task Brief — \(snapshot.project.name)

        You are picking up work on a \(snapshot.identity.kind.rawValue).
        Mission: \(snapshot.mission.statedMission)
        \(mission?.currentPhase.isEmpty == false ? "Current phase: \(mission!.currentPhase)" : "")

        ## What is actually true
        - Reality score: \(r.score)%
        - State: \(r.currentState)
        - Verification: \(snapshot.verificationSummary.verified) verified · \(snapshot.verificationSummary.failed) failed · \(snapshot.verificationSummary.unknown) unknown

        ## Top risk to address
        \(topRisk)

        ## Truth Debt / release claim boundary
        \(promptTruthDebtBoundary(for: truthDebt))

        ## In-scope areas (Applicability)
        \(snapshot.applicability.filter { $0.status.inScope }.map { "- \($0.area) (\($0.status.rawValue))" }.joined(separator: "\n"))

        ## Out of scope (do not touch)
        \(applicabilityOutOfScope(snapshot.applicability))

        ## Requested action
        \(r.nextAction)

        ## Constraints
        - Read-only by default. Do not modify the working tree without explicit approval.
        - No new external dependencies, no telemetry, no cloud services, no paid APIs.
        - Preserve the mission and verification semantics. Do not mark anything Verified without evidence.
        - When in doubt: produce a plan and ask, do not act.

        ## What to return
        1. A short diagnosis grounded in the evidence above.
        2. A minimal change plan (files touched, why, risk).
        3. A verification step that would let the user mark the related area Verified.
        \(knowledgeAddendum(knowledge))
        """
        return promptOutput(text, report: truthDebt)
    }

    private func claudePrompt(
        snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote],
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> String {
        let r = snapshot.reality
        let truthDebt = truthDebtReport(snapshot: snapshot, evidence: evidence, risks: risks, assumptions: assumptions)
        let text = """
        # Claude Handoff — \(snapshot.project.name)

        Project type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]
        Mission: \(snapshot.mission.statedMission)
        Current phase: \(snapshot.userMission?.currentPhase ?? "—")

        ## Reality summary
        - Score: \(r.score)% — \(r.currentState)
        - Verified: \(snapshot.verificationSummary.verified) · Failed: \(snapshot.verificationSummary.failed) · Unknown: \(snapshot.verificationSummary.unknown)
        - Top risks:
        \(bullets(r.topRisks))
        - Next action: \(r.nextAction)

        ## Truth Debt / release claim boundary
        \(promptTruthDebtBoundary(for: truthDebt))

        ## In scope
        \(snapshot.applicability.filter { $0.status.inScope }.map { "- \($0.area)" }.joined(separator: "\n"))

        ## Do not change
        \(applicabilityOutOfScope(snapshot.applicability))

        ## Constraints
        - Read-only by default.
        - Local-first, no telemetry, no cloud AI, no paid APIs, no external dependencies.
        - Treat your own output as Unverified until checked against local evidence.

        ## Please produce
        - An honest assessment grounded in the reality summary above.
        - A plan that respects the constraints.
        - A clear "what to verify next" so the user can update the Verification module.
        \(knowledgeAddendum(knowledge))
        """
        return promptOutput(text, report: truthDebt)
    }

    private func fixProposal(snapshot: RepoSnapshot, knowledge: [KnowledgeNote], evidence: [EvidenceRecord]) -> String {
        let topRisk = snapshot.reality.topRisks.first ?? "No top risk recorded."
        let failing = snapshot.verification.first { $0.state == .failed }
        let symptomArea = failing?.area ?? extractArea(from: topRisk) ?? "Unknown area"
        let symptomEvidence = safeInline(failing?.note ?? topRisk)
        let suggestion = suggestedSteps(for: symptomArea)
        let areaEvidence = evidence.filter { $0.area == symptomArea }
        let evidenceBlock = areaEvidence.isEmpty
            ? "- No evidence records on file for this area yet."
            : areaEvidence.prefix(8).map { record in
                let body = record.body.isEmpty ? "" : " — \(safeInline(record.body))"
                return "- [\(record.classification.rawValue)] \(safeInline(record.summary))\(body)"
            }.joined(separator: "\n")

        return """
        # Fix Proposal — \(snapshot.project.name) · \(symptomArea)

        ## Symptom
        \(symptomEvidence)

        ## Affected area
        \(symptomArea) (status: \(failing?.state.rawValue ?? "at risk"))

        ## Evidence on file
        - Reality score: \(snapshot.reality.score)%
        - Mission: \(snapshot.mission.statedMission)
        - Verification: \(snapshot.verificationSummary.verified) verified, \(snapshot.verificationSummary.failed) failed
        \(failing?.note.isEmpty == false ? "- Failure note: \(safeInline(failing!.note))" : "")
        \(failing?.verifiedBy.isEmpty == false ? "- Reported by: \(safeInline(failing!.verifiedBy))" : "")

        ## Documented evidence for \(symptomArea)
        \(evidenceBlock)

        ## Likely causes
        \(likelyCauses(for: symptomArea))

        ## Safe diagnostic steps (read-only)
        \(suggestion.diagnostics.map { "1. \($0)" }.joined(separator: "\n").replacingOccurrences(of: "1. 1.", with: "1."))

        ## Proposed fix path
        \(suggestion.fix)

        ## Verification plan
        \(suggestion.verification)

        ## Rollback
        \(suggestion.rollback)

        ## Constraints
        - Do not run destructive commands.
        - Do not commit until a developer reviews the diff.
        - Update the Verification record for "\(symptomArea)" once confirmed.
        \(knowledgeAddendum(knowledge))
        """
    }

    private func comprehensiveHandoff(
        snapshot: RepoSnapshot,
        knowledge: [KnowledgeNote],
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        decisions: [DecisionRecord],
        architecture: [ArchitectureItem],
        assumptions: [AssumptionRecord]
    ) -> String {
        let sections = handoffSections(snapshot: snapshot, knowledge: knowledge, evidence: evidence, risks: risks, decisions: decisions, architecture: architecture, assumptions: assumptions)
        let body = sections.map { "## \($0.title)\n\($0.body)" }.joined(separator: "\n\n")
        return """
        # LocalForge Comprehensive Handoff — \(snapshot.project.name)
        Generated locally by LocalForge. No data left this machine.

        \(body)
        """
    }

    private func reviewerBrief(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> String {
        let r = snapshot.reality
        let truthDebt = truthDebtReport(snapshot: snapshot, evidence: evidence, risks: risks, assumptions: assumptions)
        let text = """
        # Reviewer Brief — \(snapshot.project.name)

        - Type: \(snapshot.identity.kind.rawValue)
        - Mission: \(snapshot.mission.statedMission)
        - Reality: \(r.score)% · \(r.currentState)
        - Verified: \(snapshot.verificationSummary.verified) / Total tracked: \(snapshot.verificationSummary.total)
        - Top risk: \(r.topRisks.first ?? "None")
        - Next action: \(r.nextAction)

        ## Truth Debt / release claim boundary
        \(promptTruthDebtBoundary(for: truthDebt))

        Please confirm the top risk above and the next action. If you disagree, update the affected Verification record so Reality reflects the new truth.
        """
        return promptOutput(text, report: truthDebt)
    }

    // MARK: - Composition helpers

    private struct SuggestedSteps {
        var diagnostics: [String]
        var fix: String
        var verification: String
        var rollback: String
    }

    private func suggestedSteps(for area: String) -> SuggestedSteps {
        switch area {
        case "Preset System":
            return SuggestedSteps(
                diagnostics: [
                    "Capture the preset write path (file location, format, checksum).",
                    "Save a preset, quit Logic, reopen, diff the loaded values vs saved values.",
                    "Check `kAudioUnitProperty_ClassInfo` / state restoration code paths."
                ],
                fix: "Ensure full-state save/restore uses the AU class-info dictionary; do not rely on parameter values alone.",
                verification: "Mark `Preset System` Verified once a saved preset round-trips identically through host quit/relaunch.",
                rollback: "Revert state-restore code; presets continue to fail but no further regressions are introduced."
            )
        case "AU Validation":
            return SuggestedSteps(
                diagnostics: [
                    "Run `auval -a` to confirm the host sees the component.",
                    "Run `auval -v <type> <subtype> <manufacturer> -strict` and capture stdout.",
                    "Re-build and re-install if cached registration is stale."
                ],
                fix: "Address the first failing auval test before retrying others.",
                verification: "Mark `AU Validation` Verified once auval passes end-to-end.",
                rollback: "Revert to last passing commit; validation returns to previous baseline."
            )
        case "Build":
            return SuggestedSteps(
                diagnostics: [
                    "Run a clean build: `xcodebuild -scheme … -configuration Release clean build`.",
                    "Capture warnings and errors; identify the first error.",
                    "Check `Package.resolved` for dependency drift."
                ],
                fix: "Resolve the first compile/link error; do not chase later cascading errors.",
                verification: "Mark `Build` Verified once a clean build succeeds with no errors.",
                rollback: "Revert the most recent change touching the failing target."
            )
        case "Persistence":
            return SuggestedSteps(
                diagnostics: [
                    "Identify the storage layer (UserDefaults, file, SQLite).",
                    "Make a change, quit, relaunch; confirm the change is observable.",
                    "Inspect the on-disk artefact and confirm it contains the expected payload."
                ],
                fix: "Make sure every write path also resolves on the read path; add migrations if schema changed.",
                verification: "Mark `Persistence` Verified once data round-trips across relaunch.",
                rollback: "Restore the prior persistence code; user data continues to be readable."
            )
        default:
            return SuggestedSteps(
                diagnostics: [
                    "Reproduce the failure deliberately and capture exact steps.",
                    "Inspect logs, recent commits, and related files.",
                    "Form a single hypothesis before changing anything."
                ],
                fix: "Apply the smallest change that addresses the hypothesis. Do not refactor.",
                verification: "Mark `\(area)` Verified once the symptom is reproducibly absent.",
                rollback: "Revert the change set; behaviour returns to current baseline."
            )
        }
    }

    private func likelyCauses(for area: String) -> String {
        let causes: [String: [String]] = [
            "Preset System": [
                "Save path writes parameter values only, ignoring class-info state.",
                "Restore path reads from a stale location after a refactor.",
                "Type mismatch between saved encoding and loader."
            ],
            "AU Validation": [
                "Bundle identifier / manufacturer code mismatch in Info.plist.",
                "Missing factory function or wrong base class.",
                "Stale registration cached by AudioComponentRegistrar."
            ],
            "Build": [
                "Dependency version drift in Package.resolved.",
                "Mismatched Command Line Tools / SDK.",
                "Stale DerivedData."
            ],
            "Persistence": [
                "Schema changed without a migration.",
                "Write happens off the main actor and races with the read.",
                "File written to a sandboxed path the read cannot reach."
            ]
        ]
        let bullets = (causes[area] ?? ["No area-specific causes recorded yet — proceed by hypothesis."]).map { "- \($0)" }
        return bullets.joined(separator: "\n")
    }

    private func extractArea(from text: String) -> String? {
        // Tries to find the area name LocalForge emits in risk strings such as
        // "No verified evidence that au validation works." or "Preset System failing — …".
        let lowercase = text.lowercased()
        let areas = ["AU Validation", "Preset System", "DSP", "MIDI", "Audio I/O", "Persistence", "Build", "Signing & Notarisation", "User Interface", "Automated Tests", "API Stability"]
        return areas.first { lowercase.contains($0.lowercased()) }
    }

    private func applicabilityOutOfScope(_ items: [ApplicabilityItem]) -> String {
        let outOfScope = items.filter { $0.status == .notApplicable }
        if outOfScope.isEmpty { return "- (nothing explicitly marked out of scope)" }
        return outOfScope.map { "- \($0.area)" }.joined(separator: "\n")
    }

    private func knowledgeAddendum(_ knowledge: [KnowledgeNote]) -> String {
        guard !knowledge.isEmpty else { return "" }
        let bodies = knowledge.prefix(5).map { "- [\($0.kind.rawValue)] \(safeInline($0.title))" }.joined(separator: "\n")
        return "\n## Project knowledge already on file\n\(bodies)"
    }

    private func truthDebtReport(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> TruthDebtReport {
        TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )
    }

    private func truthDebtSection(for report: TruthDebtReport) -> HandoffSection {
        HandoffSection(title: "Truth Debt", body: """
        TruthDebtEngine status: \(safeInline(report.status.rawValue))
        Headline: \(safeInline(report.headline))
        Blockers: \(report.blockers.count)
        Caveats: \(report.caveats.count)
        Release-claim boundary: \(releaseClaimBoundary(for: report))
        Top next actions:
        \(actionBullets(report.nextActions, limit: 3))
        """)
    }

    private func releaseClaimGuardSection(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> HandoffSection {
        let report = truthDebtReport(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )
        let summary = ReleaseTruthDebtBridge().summary(for: report)
        return HandoffSection(title: "Release Claim Guard", body: """
        Release claim: \(safeInline(summary.status.rawValue))
        Claim guidance: \(safeInline(releaseClaimGuidance(for: summary.status)))
        Truth debt: \(safeInline(report.headline))
        Blockers: \(report.blockers.count) · Caveats: \(report.caveats.count) · Total gates: \(report.gates.count)
        Top blockers:
        \(releaseFindingLines(summary.topBlockers))
        Top caveats:
        \(releaseFindingLines(summary.topCaveats))
        Next action: \(safeInline(summary.recommendedNextAction))
        """)
    }

    private func releaseClaimGuidance(for status: ReleaseTruthDebtSummary.Status) -> String {
        switch status {
        case .blocked:
            "Do not describe this handoff as release-ready until the listed blocker(s) are resolved and backed by fresh local evidence."
        case .caveated:
            "A release-ready claim is caveated; carry the listed caveat(s) explicitly and refresh local evidence before external handoff."
        case .defensible:
            "No truth debt gates were detected in the current local records. This is not a release approval; keep evidence current."
        }
    }

    private func releaseFindingLines(_ findings: [ReleaseTruthDebtFinding]) -> String {
        guard !findings.isEmpty else { return "- None" }
        return findings.map { finding in
            let area = safeInline(finding.area, fallback: "")
            let areaSuffix = area.isEmpty ? "" : " · \(area)"
            return "- [\(safeInline(finding.severity.rawValue)) · \(safeInline(finding.kind.rawValue))\(areaSuffix)] \(safeInline(finding.title))"
        }.joined(separator: "\n")
    }

    private func promptTruthDebtBoundary(for report: TruthDebtReport) -> String {
        """
        - TruthDebtEngine status: \(safeInline(report.status.rawValue))
        - Blockers: \(report.blockers.count) · Caveats: \(report.caveats.count)
        - Boundary: \(releaseClaimBoundary(for: report))
        - Top next actions:
        \(actionBullets(report.nextActions, limit: 3, avoidReleaseReady: report.status != .defensible))
        """
    }

    private func releaseClaimBoundary(for report: TruthDebtReport) -> String {
        switch report.status {
        case .blocked:
            "Do not make a release claim until blockers are resolved."
        case .caveated:
            "Only make qualified release claims while caveats remain."
        case .defensible:
            "No Truth Debt gate currently prevents a release-ready claim; keep evidence current."
        }
    }

    private func actionBullets(
        _ actions: [String],
        limit: Int,
        avoidReleaseReady: Bool = false
    ) -> String {
        let cleanedActions = unique(actions)
            .prefix(max(0, limit))
            .map { action in
                avoidReleaseReady ? promptSafeInline(action) : safeInline(action)
            }
        return cleanedActions.isEmpty ? "- None" : cleanedActions.map { "- \($0)" }.joined(separator: "\n")
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let key = safeInline(value, fallback: "")
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(value)
        }

        return result
    }

    private func promptSafeInline(_ text: String) -> String {
        safeInline(text)
            .replacingOccurrences(
                of: #"(?i)claiming release-ready"#,
                with: "making a release claim",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)release-ready"#,
                with: "release claim",
                options: .regularExpression
            )
    }

    private func promptOutput(_ text: String, report: TruthDebtReport) -> String {
        guard report.status != .defensible else { return text }
        return text
            .replacingOccurrences(
                of: #"(?i)claiming release-ready"#,
                with: "making a release claim",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)release-ready"#,
                with: "release claim",
                options: .regularExpression
            )
    }

    private func safeInline(_ text: String, fallback: String = "Unknown") -> String {
        let collapsed = safeBlock(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func safeBlock(_ text: String) -> String {
        ReportEngine().redact(text)
    }

    private func gitBlock(_ git: GitStatus) -> String {
        guard git.isRepository else { return "Not a Git repository." }
        var lines: [String] = [
            "Branch: \(git.branchDisplay)",
            "Working tree: \(git.workingTreeSummary)"
        ]
        if git.hasUpstream { lines.append("Upstream: \(git.ahead) ahead, \(git.behind) behind") }
        if let hash = git.lastCommitShortHash {
            let rel = git.lastCommitRelative ?? ""
            let author = git.lastCommitAuthor ?? "?"
            let subject = git.lastCommitSubject ?? ""
            lines.append("Last commit: \(hash) \(rel) by \(author) — \(subject)")
        }
        return lines.joined(separator: "\n")
    }

    private func bullets(_ items: [String]) -> String {
        items.isEmpty ? "- None" : items.map { "- \(safeInline($0))" }.joined(separator: "\n")
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

public struct HandoffSection: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
