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

    /// Coverage that treats stale or untimestamped verified records as weaker than
    /// fresh verification. This keeps the existing count summary intact while
    /// giving trust-sensitive callers an honest recency-adjusted signal.
    public func trustAdjustedCoverage(_ records: [VerificationRecord], now: Date = Date()) -> Double {
        guard !records.isEmpty else { return 0 }
        let trustedVerified = records.reduce(0.0) { total, record in
            total + trust(for: record, now: now)
        }
        return trustedVerified / Double(records.count)
    }

    public func trust(for record: VerificationRecord, now: Date = Date()) -> Double {
        trust(for: record.state, updatedAt: record.updatedAt, now: now)
    }

    /// Trust for a verification state when timestamp provenance may be missing
    /// before it is materialized into a `VerificationRecord`.
    public func trust(for state: VerificationState, updatedAt: Date?, now: Date = Date()) -> Double {
        guard state == .verified else { return 0 }
        return age(for: state, updatedAt: updatedAt, now: now).trust
    }

    public func age(for state: VerificationState, updatedAt: Date?, now: Date = Date()) -> VerificationAge {
        state == .unknown ? .never : VerificationAge.from(updatedAt, now: now)
    }

    public func recencyCaveats(_ records: [VerificationRecord], now: Date = Date()) -> [String] {
        records.compactMap { record in
            recencyCaveat(area: record.area, state: record.state, updatedAt: record.updatedAt, now: now)
        }
    }

    public func recencyCaveat(
        area: String,
        state: VerificationState,
        updatedAt: Date?,
        now: Date = Date()
    ) -> String? {
        guard state == .verified else { return nil }
        switch age(for: state, updatedAt: updatedAt, now: now) {
        case .fresh, .recent:
            return nil
        case .ageing:
            return "\(area) verification is ageing; trust is reduced until refreshed."
        case .stale:
            return "\(area) verification is stale; re-confirm before treating it as current proof."
        case .expired:
            return "\(area) verification is expired; treat it as untrusted until re-confirmed."
        case .never:
            return "\(area) verification has no timestamp; treat it as untrusted until re-confirmed."
        }
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
