import Foundation

/// Phase 8.5: read-only diagnostics engine that detects truth decay, evidence
/// decay, register decay, assumption decay, architecture drift, and dependency
/// issues across all projects in the workspace.
public struct WorkspaceHealthEngine: Sendable {
    private static let staleVerificationDays = 90
    private static let oldAssumptionDays = 60

    public init() {}

    public func report(
        projects: [PersistedProjectRecord],
        projectNames: [UUID: String]
    ) -> WorkspaceHealthReport {
        var issues: [WorkspaceHealthIssue] = []

        for record in projects {
            let pid = record.id
            let pname = projectNames[pid] ?? record.name

            issues += truthDecay(record: record, pid: pid, pname: pname)
            issues += evidenceDecay(record: record, pid: pid, pname: pname)
            issues += registerDecay(record: record, pid: pid, pname: pname)
            issues += assumptionDecay(record: record, pid: pid, pname: pname)
            issues += architectureDrift(record: record, pid: pid, pname: pname)
            issues += dependencyIssues(record: record, pid: pid, pname: pname)
        }

        issues.sort { lhs, rhs in
            if lhs.severity != rhs.severity {
                let order: [HealthIssueSeverity] = [.critical, .high, .medium, .low]
                let li = order.firstIndex(of: lhs.severity) ?? 4
                let ri = order.firstIndex(of: rhs.severity) ?? 4
                return li < ri
            }
            return lhs.projectName < rhs.projectName
        }

        return WorkspaceHealthReport(issues: issues)
    }

    // MARK: - Truth Decay

    private func truthDecay(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []
        let now = Date()
        let threshold = TimeInterval(Self.staleVerificationDays * 86_400)

        let stale = (record.verification ?? []).filter { v in
            v.state == .verified && now.timeIntervalSince(v.updatedAt) > threshold
        }
        if !stale.isEmpty {
            issues.append(.init(
                category: .truthDecay,
                severity: stale.count > 5 ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(stale.count) stale verification(s)",
                detail: "Areas last verified >90 days ago: \(stale.prefix(3).map(\.area).joined(separator: ", "))\(stale.count > 3 ? " and \(stale.count - 3) more" : "").",
                recommendation: "Re-verify or mark as unknown if the area is no longer relevant."
            ))
        }

        let failed = (record.verification ?? []).filter { $0.state == .failed }
        if !failed.isEmpty {
            issues.append(.init(
                category: .truthDecay,
                severity: failed.count >= 3 ? .critical : .high,
                projectID: pid,
                projectName: pname,
                title: "\(failed.count) failed verification(s) unresolved",
                detail: "Areas: \(failed.prefix(3).map(\.area).joined(separator: ", "))\(failed.count > 3 ? " and \(failed.count - 3) more" : "").",
                recommendation: "Resolve failures or log them as open risks."
            ))
        }

        if record.mission == nil, !(record.verification?.isEmpty ?? true) {
            issues.append(.init(
                category: .truthDecay,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "No mission defined",
                detail: "Project has verification records but no stated mission.",
                recommendation: "Run the Setup Wizard to define a mission and give verification context."
            ))
        }

        return issues
    }

    // MARK: - Evidence Decay

    private func evidenceDecay(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []
        let evidence = record.evidence ?? []

        let missingFile = evidence.filter { e in
            !e.attachmentPath.isEmpty && !FileManager.default.fileExists(atPath: e.attachmentPath)
        }
        if !missingFile.isEmpty {
            issues.append(.init(
                category: .evidenceDecay,
                severity: .high,
                projectID: pid,
                projectName: pname,
                title: "\(missingFile.count) evidence attachment(s) not found",
                detail: "Files no longer exist at recorded paths.",
                recommendation: "Update the attachment path or remove the stale reference."
            ))
        }

        let verifiedWithNoEvidence = (record.verification ?? []).filter { v in
            v.state == .verified && evidence.filter { $0.area == v.area }.isEmpty
        }
        if !verifiedWithNoEvidence.isEmpty {
            issues.append(.init(
                category: .evidenceDecay,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "\(verifiedWithNoEvidence.count) verified area(s) have no evidence",
                detail: "Areas: \(verifiedWithNoEvidence.prefix(3).map(\.area).joined(separator: ", "))\(verifiedWithNoEvidence.count > 3 ? "…" : "").",
                recommendation: "Add at least one evidence record to back each verified area."
            ))
        }

        return issues
    }

    // MARK: - Register Decay

    private func registerDecay(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []

        let risksNoMitigation = (record.risks ?? []).filter { r in
            r.status == .open && r.mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !risksNoMitigation.isEmpty {
            issues.append(.init(
                category: .registerDecay,
                severity: risksNoMitigation.count > 3 ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(risksNoMitigation.count) open risk(s) missing mitigation",
                detail: "Open risks need a mitigation plan to be actionable.",
                recommendation: "Add mitigation plans or accept/close risks that are no longer relevant."
            ))
        }

        let risksNoOwner = (record.risks ?? []).filter { r in
            r.status == .open && r.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !risksNoOwner.isEmpty {
            issues.append(.init(
                category: .registerDecay,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(risksNoOwner.count) open risk(s) have no owner",
                detail: "Unowned risks are less likely to be actioned.",
                recommendation: "Assign an owner to each open risk."
            ))
        }

        let decisionsNoReason = (record.decisions ?? []).filter { d in
            d.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !decisionsNoReason.isEmpty {
            issues.append(.init(
                category: .registerDecay,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(decisionsNoReason.count) decision(s) missing rationale",
                detail: "Decisions without a stated reason lose their value over time.",
                recommendation: "Add a rationale to each decision record."
            ))
        }

        return issues
    }

    // MARK: - Assumption Decay

    private func assumptionDecay(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []
        let now = Date()
        let threshold = TimeInterval(Self.oldAssumptionDays * 86_400)

        let oldActive = (record.assumptions ?? []).filter { a in
            a.status == .active && now.timeIntervalSince(a.updatedAt) > threshold
        }
        if !oldActive.isEmpty {
            issues.append(.init(
                category: .assumptionDecay,
                severity: oldActive.count > 3 ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(oldActive.count) active assumption(s) unchanged for >60 days",
                detail: "Old unverified assumptions become silent risk.",
                recommendation: "Review assumptions: verify, disprove, or mark as superseded."
            ))
        }

        let activeNoVerificationPlan = (record.assumptions ?? []).filter { a in
            a.status == .active && a.verificationNeeded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !activeNoVerificationPlan.isEmpty {
            issues.append(.init(
                category: .assumptionDecay,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(activeNoVerificationPlan.count) active assumption(s) have no verification plan",
                detail: "Without a verification plan, assumptions may never be resolved.",
                recommendation: "Add a verification plan to each active assumption."
            ))
        }

        return issues
    }

    // MARK: - Architecture Drift

    private func architectureDrift(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []

        let failing = (record.architecture ?? []).filter { $0.status == .failing }
        if !failing.isEmpty {
            issues.append(.init(
                category: .architectureDrift,
                severity: failing.count > 2 ? .critical : .high,
                projectID: pid,
                projectName: pname,
                title: "\(failing.count) architecture component(s) marked Failing",
                detail: "Components: \(failing.prefix(3).map(\.name).joined(separator: ", "))\(failing.count > 3 ? "…" : "").",
                recommendation: "Resolve failing components or log as risks."
            ))
        }

        let needsReview = (record.architecture ?? []).filter { $0.status == .needsReview }
        if !needsReview.isEmpty {
            issues.append(.init(
                category: .architectureDrift,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "\(needsReview.count) architecture component(s) need review",
                detail: "Components flagged for review: \(needsReview.prefix(3).map(\.name).joined(separator: ", "))\(needsReview.count > 3 ? "…" : "").",
                recommendation: "Review and update the status of each component."
            ))
        }

        let archWithNoVerification = (record.architecture ?? []).filter { a in
            a.linkedVerificationAreas.isEmpty && a.status == .live
        }
        if archWithNoVerification.count > 3 {
            issues.append(.init(
                category: .architectureDrift,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(archWithNoVerification.count) live component(s) not linked to verification",
                detail: "Architecture components without verification links may drift undetected.",
                recommendation: "Link architecture components to relevant verification areas."
            ))
        }

        return issues
    }

    // MARK: - Dependency Issues

    private func dependencyIssues(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceHealthIssue] {
        var issues: [WorkspaceHealthIssue] = []
        let verification = record.verification ?? []
        let areaNames = Set(verification.map(\.area))

        var brokenChains: [String] = []
        for v in verification {
            for dep in v.dependsOn where !dep.isEmpty {
                if !areaNames.contains(dep) {
                    brokenChains.append("\(v.area) → \(dep) (missing)")
                }
            }
        }
        if !brokenChains.isEmpty {
            issues.append(.init(
                category: .dependencyIssues,
                severity: .high,
                projectID: pid,
                projectName: pname,
                title: "\(brokenChains.count) broken dependency chain(s)",
                detail: brokenChains.prefix(3).joined(separator: "; ") + (brokenChains.count > 3 ? "…" : ""),
                recommendation: "Repair or remove dependency references to non-existent areas."
            ))
        }

        let evidenceIDs = Set((record.evidence ?? []).map(\.id))
        var orphanLinks: [String] = []
        for r in record.risks ?? [] {
            for eid in r.linkedEvidenceIDs where !evidenceIDs.contains(eid) {
                orphanLinks.append("Risk '\(r.title)' references missing evidence")
            }
        }
        if !orphanLinks.isEmpty {
            issues.append(.init(
                category: .dependencyIssues,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "\(orphanLinks.count) broken cross-link(s) in risks",
                detail: orphanLinks.prefix(3).joined(separator: "; ") + (orphanLinks.count > 3 ? "…" : ""),
                recommendation: "Remove stale links or restore the missing records."
            ))
        }

        return issues
    }
}
