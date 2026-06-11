import Foundation

/// Phase 8.5: read-only integrity diagnostics. Detects broken links, orphan
/// records, invalid dates, duplicates, corrupt relationships. Never auto-fixes.
public struct WorkspaceDoctorEngine: Sendable {
    public init() {}

    public func diagnose(records: [PersistedProjectRecord], projectNames: [UUID: String]) -> WorkspaceDoctorReport {
        var issues: [WorkspaceDoctorIssue] = []

        for record in records {
            let pid = record.id
            let pname = projectNames[pid] ?? record.name
            issues += brokenLinks(record: record, pid: pid, pname: pname)
            issues += orphans(record: record, pid: pid, pname: pname)
            issues += duplicates(record: record, pid: pid, pname: pname)
            issues += invalidDates(record: record, pid: pid, pname: pname)
        }

        issues.sort {
            let order: [HealthIssueSeverity] = [.critical, .high, .medium, .low]
            let li = order.firstIndex(of: $0.severity) ?? 4
            let ri = order.firstIndex(of: $1.severity) ?? 4
            return li < ri
        }

        return WorkspaceDoctorReport(issues: issues, projectsChecked: records.count)
    }

    // MARK: - Broken links

    private func brokenLinks(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        var issues: [WorkspaceDoctorIssue] = []
        let evidenceIDs = Set((record.evidence ?? []).map(\.id))
        let riskIDs = Set((record.risks ?? []).map(\.id))
        let decisionIDs = Set((record.decisions ?? []).map(\.id))
        let archIDs = Set((record.architecture ?? []).map(\.id))
        let verificationIDs = Set((record.verification ?? []).map(\.id))

        var broken = 0

        // Evidence cross-links.
        for e in record.evidence ?? [] {
            broken += e.linkedRiskIDs.filter { !riskIDs.contains($0) }.count
            broken += e.linkedDecisionIDs.filter { !decisionIDs.contains($0) }.count
            broken += e.linkedArchitectureIDs.filter { !archIDs.contains($0) }.count
            broken += e.linkedVerificationIDs.filter { !verificationIDs.contains($0) }.count
        }
        // Risk cross-links.
        for r in record.risks ?? [] {
            broken += r.linkedEvidenceIDs.filter { !evidenceIDs.contains($0) }.count
            broken += r.linkedDecisionIDs.filter { !decisionIDs.contains($0) }.count
            broken += r.linkedArchitectureIDs.filter { !archIDs.contains($0) }.count
            broken += r.linkedVerificationIDs.filter { !verificationIDs.contains($0) }.count
        }
        // Decision cross-links.
        for d in record.decisions ?? [] {
            broken += d.linkedEvidenceIDs.filter { !evidenceIDs.contains($0) }.count
            broken += d.linkedRiskIDs.filter { !riskIDs.contains($0) }.count
            broken += d.linkedArchitectureIDs.filter { !archIDs.contains($0) }.count
        }

        if broken > 0 {
            issues.append(.init(
                kind: .brokenLink,
                severity: broken > 5 ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(broken) broken cross-link(s) detected",
                impact: "Related records appear linked but the target no longer exists. Confidence and reality scores may be inaccurate.",
                recommendation: "Remove or repair stale cross-links in the affected records."
            ))
        }

        // Missing attachment files.
        let missingAttachments = (record.evidence ?? []).filter { e in
            !e.attachmentPath.isEmpty && !FileManager.default.fileExists(atPath: e.attachmentPath)
        }
        if !missingAttachments.isEmpty {
            issues.append(.init(
                kind: .missingAttachment,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "\(missingAttachments.count) attachment path(s) not found on disk",
                impact: "Evidence records reference files that no longer exist at their recorded path.",
                recommendation: "Update the attachment path or remove the stale reference."
            ))
        }

        // Broken verification dependency chains.
        let areaNames = Set((record.verification ?? []).map(\.area))
        let brokenDeps = (record.verification ?? []).flatMap { v in
            v.dependsOn.filter { !$0.isEmpty && !areaNames.contains($0) }.map { dep in
                "\(v.area) → \(dep)"
            }
        }
        if !brokenDeps.isEmpty {
            issues.append(.init(
                kind: .brokenDependencyChain,
                severity: .high,
                projectID: pid,
                projectName: pname,
                title: "\(brokenDeps.count) broken verification dependency chain(s)",
                impact: "Dependencies reference verification areas that do not exist. Release blocking logic may be incomplete.",
                recommendation: "Update or remove dependency references to non-existent areas."
            ))
        }

        return issues
    }

    // MARK: - Orphan records

    private func orphans(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        var issues: [WorkspaceDoctorIssue] = []
        let areas = Set((record.verification ?? []).map(\.area))

        // Evidence with area that no verification record references.
        let orphanEvidence = (record.evidence ?? []).filter { e in
            !e.area.isEmpty && !areas.contains(e.area)
        }
        if !orphanEvidence.isEmpty {
            issues.append(.init(
                kind: .orphanEvidence,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(orphanEvidence.count) evidence record(s) reference unknown areas",
                impact: "Evidence is not linked to any verification area and will not contribute to confidence or reality scores.",
                recommendation: "Update the area field to match an existing verification area."
            ))
        }

        // Risks with no area link and no cross-links.
        let orphanRisks = (record.risks ?? []).filter { r in
            r.linkedVerificationAreas.isEmpty && r.linkedEvidenceIDs.isEmpty && r.linkedVerificationIDs.isEmpty
        }
        if orphanRisks.count > 2 {
            issues.append(.init(
                kind: .orphanRisk,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(orphanRisks.count) risk(s) have no links to verification or evidence",
                impact: "Unlinked risks are not traceable through the truth chain.",
                recommendation: "Link risks to verification areas or evidence records."
            ))
        }

        return issues
    }

    // MARK: - Duplicate records

    private func duplicates(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        var issues: [WorkspaceDoctorIssue] = []

        // Duplicate verification areas.
        let areas = (record.verification ?? []).map { $0.area.lowercased() }
        let dupAreas = findDuplicates(in: areas)
        if !dupAreas.isEmpty {
            issues.append(.init(
                kind: .duplicateRecord,
                severity: .medium,
                projectID: pid,
                projectName: pname,
                title: "\(dupAreas.count) duplicate verification area(s)",
                impact: "Duplicate areas cause ambiguity in release readiness and dependency resolution.",
                recommendation: "Merge or rename duplicate verification areas."
            ))
        }

        // Duplicate risk titles.
        let riskTitles = (record.risks ?? []).map { $0.title.lowercased() }
        let dupRisks = findDuplicates(in: riskTitles)
        if !dupRisks.isEmpty {
            issues.append(.init(
                kind: .duplicateRecord,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(dupRisks.count) duplicate risk title(s)",
                impact: "Duplicate risks may lead to double-counting in health assessments.",
                recommendation: "Merge or differentiate risks with identical titles."
            ))
        }

        return issues
    }

    // MARK: - Invalid dates

    private func invalidDates(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        let now = Date()
        let farFuture = now.addingTimeInterval(365 * 86_400)
        let distantPast = Date(timeIntervalSince1970: 0)
        var invalid = 0

        for v in record.verification ?? [] {
            if v.updatedAt > farFuture || v.updatedAt < distantPast { invalid += 1 }
        }
        for e in record.evidence ?? [] {
            if e.createdAt > farFuture || e.createdAt < distantPast { invalid += 1 }
        }

        if invalid > 0 {
            return [.init(
                kind: .invalidDate,
                severity: .low,
                projectID: pid,
                projectName: pname,
                title: "\(invalid) record(s) have suspicious dates",
                impact: "Incorrect dates affect age calculations, staleness detection, and timeline ordering.",
                recommendation: "Review and correct dates on affected records."
            )]
        }
        return []
    }

    // MARK: - Helpers

    private func findDuplicates(in values: [String]) -> [String] {
        var seen = Set<String>()
        var dups = Set<String>()
        for v in values {
            if !seen.insert(v).inserted { dups.insert(v) }
        }
        return Array(dups)
    }
}
