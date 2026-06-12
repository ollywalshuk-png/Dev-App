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
            issues += trustIntegrity(record: record, pid: pid, pname: pname)
            issues += truthDebt(record: record, pid: pid, pname: pname)
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

    // MARK: - Trust integrity

    private func trustIntegrity(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        var issues: [WorkspaceDoctorIssue] = []
        let evidence = record.evidence ?? []
        let verification = record.verification ?? []
        let risks = record.risks ?? []
        let recommendations = record.recommendations ?? []
        let evidenceIDs = Set(evidence.map(\.id))

        let staleUnbacked = verification.filter { v in
            guard v.state == .verified else { return false }
            let age = VerificationAge.from(v.updatedAt)
            guard age == .stale || age == .expired else { return false }
            return !hasEvidence(for: v, in: evidence)
        }
        if !staleUnbacked.isEmpty {
            issues.append(.init(
                kind: .missingReference,
                severity: staleUnbacked.contains { VerificationAge.from($0.updatedAt) == .expired } ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(staleUnbacked.count) stale verified area(s) have no evidence",
                impact: "Verification remains marked Verified after trust decay, but no evidence record backs it. Release-readiness users may over-trust stale truth.",
                recommendation: "Attach recent evidence or move stale areas back to In Progress or Unknown until re-verified."
            ))
        }

        let unlinkedHighImpactRisks = risks.filter { risk in
            isActiveHighImpactRisk(risk) && !hasRiskTruthLinks(risk)
        }
        if !unlinkedHighImpactRisks.isEmpty {
            issues.append(.init(
                kind: .orphanRisk,
                severity: unlinkedHighImpactRisks.contains { $0.impact == .critical } ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(unlinkedHighImpactRisks.count) high-impact active risk(s) have no truth links",
                impact: "High or Critical active risks are not tied to evidence, verification, decisions, or architecture. Release blockers may be hard to trace or resolve.",
                recommendation: "Link each risk to the relevant evidence, verification area, decision, or architecture record."
            ))
        }

        let conflictingAreas = duplicateVerificationGroups(in: verification).filter { group in
            Set(group.map(\.state)).count > 1
        }
        if !conflictingAreas.isEmpty {
            issues.append(.init(
                kind: .corruptRelationship,
                severity: .high,
                projectID: pid,
                projectName: pname,
                title: "\(conflictingAreas.count) verification area(s) have conflicting states",
                impact: "Multiple records for the same area disagree on truth state. Readiness and confidence views may show whichever duplicate is read first.",
                recommendation: "Merge duplicate verification rows and keep one current state per area."
            ))
        }

        let recommendationsWithMissingEvidence = recommendations.filter { recommendation in
            recommendation.relatedEvidenceIDs.contains { !evidenceIDs.contains($0) }
        }
        if !recommendationsWithMissingEvidence.isEmpty {
            issues.append(.init(
                kind: .missingReference,
                severity: recommendationsWithMissingEvidence.contains { isHighSeveritySafetyRecommendation($0) } ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(recommendationsWithMissingEvidence.count) recommendation(s) reference missing evidence",
                impact: "Actionable advice points at evidence records that no longer exist. Safety and release recommendations may be stale or unverifiable.",
                recommendation: "Restore the evidence records or remove stale relatedEvidenceIDs from the recommendation."
            ))
        }

        let orphanedSafetyRecommendations = recommendations.filter { recommendation in
            isActiveSafetyRecommendation(recommendation)
                && isBlank(recommendation.targetPath)
                && isBlank(recommendation.evidenceSummary)
                && recommendation.relatedEvidenceIDs.isEmpty
        }
        if !orphanedSafetyRecommendations.isEmpty {
            issues.append(.init(
                kind: .missingReference,
                severity: orphanedSafetyRecommendations.contains { $0.severity.rank >= RecommendationSeverity.high.rank } ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(orphanedSafetyRecommendations.count) active safety recommendation(s) have no evidence target",
                impact: "Safety recommendations without a path, evidence summary, or related evidence cannot be audited before action.",
                recommendation: "Attach evidence or close the recommendation if its source finding no longer exists."
            ))
        }

        return issues
    }

    // MARK: - Truth debt

    private func truthDebt(record: PersistedProjectRecord, pid: UUID, pname: String) -> [WorkspaceDoctorIssue] {
        var issues: [WorkspaceDoctorIssue] = []
        let evidence = record.evidence ?? []
        let verification = record.verification ?? []
        let risks = record.risks ?? []
        let assumptions = record.assumptions ?? []

        let releaseBlockingRisks = risks.filter(\.isReleaseBlocking)
        let highImpactRisks = risks.filter(isActiveHighImpactRisk)
        let releaseBlockingRiskIDs = Set(releaseBlockingRisks.map(\.id))
        let highImpactRiskIDs = Set(highImpactRisks.map(\.id))
        let highOrReleaseRiskIDs = releaseBlockingRiskIDs.union(highImpactRiskIDs)
        let releaseBlockingAreaKeys = Set(releaseBlockingRisks.flatMap(\.linkedVerificationAreas).map(normalizedArea).filter { !$0.isEmpty })
        let highImpactAreaKeys = Set(highImpactRisks.flatMap(\.linkedVerificationAreas).map(normalizedArea).filter { !$0.isEmpty })
        let highOrReleaseAreaKeys = releaseBlockingAreaKeys.union(highImpactAreaKeys)

        let staleHighPriorityVerified = verification.filter { v in
            guard v.state == .verified else { return false }
            guard highOrReleaseAreaKeys.contains(normalizedArea(v.area)) else { return false }
            let age = VerificationAge.from(v.updatedAt)
            guard age == .stale || age == .expired else { return false }
            return !hasStrongEvidence(for: v, in: evidence)
        }
        if !staleHighPriorityVerified.isEmpty {
            issues.append(.init(
                kind: .missingReference,
                severity: staleHighPriorityVerified.contains { VerificationAge.from($0.updatedAt) == .expired } ? .critical : .high,
                projectID: pid,
                projectName: pname,
                title: "\(staleHighPriorityVerified.count) release-relevant verified area(s) have stale truth without strong evidence",
                impact: "Critical or high-impact risk areas remain marked Verified after trust decay, but no observed, measured, or verified evidence backs the current claim.",
                recommendation: "Refresh the verification with strong evidence, or move the area out of Verified until it is re-checked."
            ))
        }

        let verificationIDsByArea = Dictionary(grouping: verification, by: { normalizedArea($0.area) })
            .mapValues { Set($0.map(\.id)) }
        let highOrReleaseVerificationIDs = highOrReleaseAreaKeys.reduce(into: Set<UUID>()) { ids, areaKey in
            ids.formUnion(verificationIDsByArea[areaKey] ?? [])
        }
        let activeReleaseRelevantAssumptions = assumptions.filter { assumption in
            guard assumption.status == .active else { return false }
            let linkedAreaKey = normalizedArea(assumption.linkedVerificationArea)
            return (!linkedAreaKey.isEmpty && highOrReleaseAreaKeys.contains(linkedAreaKey))
                || assumption.linkedRiskIDs.contains { highOrReleaseRiskIDs.contains($0) }
                || assumption.linkedVerificationIDs.contains { highOrReleaseVerificationIDs.contains($0) }
        }
        if !activeReleaseRelevantAssumptions.isEmpty {
            issues.append(.init(
                kind: .missingReference,
                severity: activeReleaseRelevantAssumptions.contains { assumption in
                    assumption.linkedRiskIDs.contains { releaseBlockingRiskIDs.contains($0) }
                        || releaseBlockingAreaKeys.contains(normalizedArea(assumption.linkedVerificationArea))
                } ? .high : .medium,
                projectID: pid,
                projectName: pname,
                title: "\(activeReleaseRelevantAssumptions.count) active assumption(s) are linked to release-relevant risk areas",
                impact: "The release-ready claim depends on unresolved assumptions tied to critical/high risk areas or release-blocking risks.",
                recommendation: "Convert each assumption into evidence, verify or disprove it, or remove the risk/area link if it no longer applies."
            ))
        }

        let releaseBlockingRisksWithGaps = releaseBlockingRisks.filter { risk in
            lacksMitigationAndContingency(risk) || !hasVerificationOrEvidenceSupport(risk, verification: verification, evidence: evidence)
        }
        if !releaseBlockingRisksWithGaps.isEmpty {
            issues.append(.init(
                kind: .orphanRisk,
                severity: releaseBlockingRisksWithGaps.contains { $0.impact == .critical } ? .critical : .high,
                projectID: pid,
                projectName: pname,
                title: "\(releaseBlockingRisksWithGaps.count) release-blocking open risk(s) lack mitigation or verification support",
                impact: "Open release-blocking risks need an explicit mitigation or contingency and a verification/evidence link before a release-ready claim is defensible.",
                recommendation: "Add a mitigation or contingency, link verification/evidence, or close the risk when it no longer blocks release."
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

    private func hasEvidence(for verification: VerificationRecord, in evidence: [EvidenceRecord]) -> Bool {
        let area = normalizedArea(verification.area)
        return evidence.contains { e in
            normalizedArea(e.area) == area
                || e.linkedVerificationIDs.contains(verification.id)
                || e.linkedID == verification.id
        }
    }

    private func hasStrongEvidence(for verification: VerificationRecord, in evidence: [EvidenceRecord]) -> Bool {
        let area = normalizedArea(verification.area)
        return evidence.contains { e in
            isStrongEvidence(e)
                && (
                    normalizedArea(e.area) == area
                        || e.linkedVerificationIDs.contains(verification.id)
                        || e.linkedID == verification.id
                )
        }
    }

    private func isStrongEvidence(_ evidence: EvidenceRecord) -> Bool {
        evidence.classification == .observed
            || evidence.classification == .measured
            || evidence.classification == .verified
    }

    private func isActiveHighImpactRisk(_ risk: RiskRecord) -> Bool {
        (risk.status == .open || risk.status == .monitoring)
            && (risk.impact == .high || risk.impact == .critical)
    }

    private func hasRiskTruthLinks(_ risk: RiskRecord) -> Bool {
        !risk.linkedVerificationAreas.filter { !isBlank($0) }.isEmpty
            || !risk.linkedEvidenceIDs.isEmpty
            || !risk.linkedVerificationIDs.isEmpty
            || !risk.linkedDecisionIDs.isEmpty
            || !risk.linkedArchitectureIDs.isEmpty
    }

    private func lacksMitigationAndContingency(_ risk: RiskRecord) -> Bool {
        isBlank(risk.mitigation) && isBlank(risk.contingency)
    }

    private func hasVerificationOrEvidenceSupport(_ risk: RiskRecord, verification: [VerificationRecord], evidence: [EvidenceRecord]) -> Bool {
        let verificationIDs = Set(verification.map(\.id))
        let verificationAreaKeys = Set(verification.map { normalizedArea($0.area) })
        let evidenceIDs = Set(evidence.map(\.id))

        return risk.linkedVerificationIDs.contains { verificationIDs.contains($0) }
            || risk.linkedVerificationAreas.contains { verificationAreaKeys.contains(normalizedArea($0)) }
            || risk.linkedEvidenceIDs.contains { evidenceIDs.contains($0) }
    }

    private func duplicateVerificationGroups(in verification: [VerificationRecord]) -> [[VerificationRecord]] {
        let groups = Dictionary(grouping: verification) { normalizedArea($0.area) }
        return groups.values.filter { group in
            guard let first = group.first else { return false }
            return !normalizedArea(first.area).isEmpty && group.count > 1
        }
    }

    private func isActiveSafetyRecommendation(_ recommendation: RecommendationRecord) -> Bool {
        recommendation.category == .safety
            && recommendation.approvalState != .completed
            && recommendation.approvalState != .rejected
    }

    private func isHighSeveritySafetyRecommendation(_ recommendation: RecommendationRecord) -> Bool {
        recommendation.category == .safety
            && recommendation.severity.rank >= RecommendationSeverity.high.rank
    }

    private func normalizedArea(_ area: String) -> String {
        area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
