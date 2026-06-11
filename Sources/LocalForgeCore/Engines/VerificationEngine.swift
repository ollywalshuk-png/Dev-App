import Foundation

/// Builds and maintains the list of areas a project should verify. Areas are
/// seeded from what actually matters (the applicability matrix), then overlaid
/// with whatever the user has recorded. This is the spine of the command centre:
/// not scanning, but tracking what has genuinely been verified.
public struct VerificationEngine: Sendable {
    public init() {}

    /// The areas worth tracking for a project: every in-scope applicability area.
    public func trackedAreas(for applicability: [ApplicabilityItem]) -> [String] {
        applicability.filter { $0.status.inScope }.map(\.area)
    }

    /// Produce the full, ordered verification list: one record per tracked area,
    /// using the user's saved state where present, otherwise Unknown. Saved
    /// records for areas no longer in scope are preserved at the end.
    public func reconcile(
        applicability: [ApplicabilityItem],
        saved: [VerificationRecord]
    ) -> [VerificationRecord] {
        let savedByArea = Dictionary(saved.map { ($0.area, $0) }, uniquingKeysWith: { first, _ in first })
        let areas = trackedAreas(for: applicability)

        var result: [VerificationRecord] = areas.map { area in
            savedByArea[area] ?? VerificationRecord(area: area)
        }

        // Keep any user-recorded areas that are no longer in scope (custom or stale).
        let trackedSet = Set(areas)
        for record in saved where !trackedSet.contains(record.area) {
            result.append(record)
        }
        return result
    }

    public func summary(_ records: [VerificationRecord]) -> VerificationSummary {
        VerificationSummary(records: records)
    }

    public func timeline(_ records: [VerificationRecord]) -> [VerificationRecord] {
        records.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.area < rhs.area
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
