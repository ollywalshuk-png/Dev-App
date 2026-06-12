import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Verification recency trust")
struct VerificationRecencyTrustTests {
    @Test("trust adjusted coverage discounts stale verified records")
    func trustAdjustedCoverageDiscountsStaleVerifiedRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = VerificationRecord(
            area: "Build",
            state: .verified,
            updatedAt: now.addingTimeInterval(-recencyDay)
        )
        let stale = VerificationRecord(
            area: "Automated Tests",
            state: .verified,
            updatedAt: now.addingTimeInterval(-120 * recencyDay)
        )
        let expired = VerificationRecord(
            area: "Release Smoke Test",
            state: .verified,
            updatedAt: now.addingTimeInterval(-220 * recencyDay)
        )
        let engine = VerificationEngine()

        let rawCoverage = engine.summary([fresh, stale]).coverage
        let adjustedCoverage = engine.trustAdjustedCoverage([fresh, stale], now: now)

        #expect(rawCoverage == 1)
        #expect(approximately(engine.trustAdjustedCoverage([fresh], now: now), 1))
        #expect(approximately(engine.trustAdjustedCoverage([stale], now: now), 0.25))
        #expect(approximately(adjustedCoverage, 0.625))
        #expect(adjustedCoverage < rawCoverage)

        let caveats = engine.recencyCaveats([fresh, stale, expired], now: now)
        #expect(caveats.count == 2)
        #expect(caveats.contains { $0.localizedCaseInsensitiveContains("stale") })
        #expect(caveats.contains { $0.localizedCaseInsensitiveContains("expired") })
    }

    @Test("untimestamped verified evidence is not treated as fresh")
    func untimestampedVerifiedEvidenceIsNotTreatedAsFresh() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let engine = VerificationEngine()
        let freshTrust = engine.trust(
            for: .verified,
            updatedAt: now.addingTimeInterval(-recencyDay),
            now: now
        )
        let missingTimestampTrust = engine.trust(for: .verified, updatedAt: nil, now: now)
        let caveat = engine.recencyCaveat(
            area: "Manual QA",
            state: .verified,
            updatedAt: nil,
            now: now
        )

        #expect(engine.age(for: .verified, updatedAt: nil, now: now) == .never)
        #expect(freshTrust == 1)
        #expect(missingTimestampTrust == 0)
        #expect(missingTimestampTrust < freshTrust)
        #expect(caveat?.localizedCaseInsensitiveContains("no timestamp") == true)
        #expect(engine.recencyCaveat(area: "Manual QA", state: .unknown, updatedAt: nil, now: now) == nil)
    }

    private func approximately(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.000_001
    }
}

private let recencyDay: TimeInterval = 86_400
