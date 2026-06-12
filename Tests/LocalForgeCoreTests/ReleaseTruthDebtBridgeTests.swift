import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Release truth debt bridge")
struct ReleaseTruthDebtBridgeTests {
    @Test("blocked report exposes top blockers before caveats")
    func blockedReportExposesTopBlockersBeforeCaveats() throws {
        let critical = gate(
            kind: .releaseBlockingRisk,
            severity: .critical,
            area: "Signing",
            title: "Notarisation fails",
            recommendedAction: "Resolve notarisation before release.",
            blocksReleaseClaim: true
        )
        let high = gate(
            kind: .missingEvidence,
            severity: .high,
            area: "Build",
            title: "Build lacks evidence",
            recommendedAction: "Attach measured build evidence.",
            blocksReleaseClaim: true
        )
        let medium = gate(
            kind: .activeAssumption,
            severity: .medium,
            area: "Docs",
            title: "Docs assume screenshots are current",
            recommendedAction: "Refresh screenshots.",
            blocksReleaseClaim: false
        )

        let summary = ReleaseTruthDebtBridge().summary(
            for: TruthDebtReport(gates: [medium, high, critical]),
            topLimit: 1
        )

        #expect(summary.status == .blocked)
        #expect(summary.topBlockers.map(\.title) == ["Notarisation fails"])
        #expect(summary.topCaveats.map(\.title) == ["Docs assume screenshots are current"])
        #expect(summary.recommendedNextAction == "Resolve notarisation before release.")

        let blocker = try #require(summary.topBlockers.first)
        #expect(blocker.kind == .releaseBlockingRisk)
        #expect(blocker.severity == .critical)
        #expect(blocker.area == "Signing")
    }

    @Test("caveated report recommends the highest priority caveat")
    func caveatedReportRecommendsHighestPriorityCaveat() {
        let low = gate(
            kind: .unverifiedArea,
            severity: .low,
            area: "Docs",
            title: "Docs are unknown",
            recommendedAction: "Verify docs.",
            blocksReleaseClaim: false
        )
        let medium = gate(
            kind: .staleVerification,
            severity: .medium,
            area: "Telemetry",
            title: "Telemetry is stale",
            recommendedAction: "Refresh telemetry evidence.",
            blocksReleaseClaim: false
        )

        let summary = ReleaseTruthDebtBridge().summary(for: TruthDebtReport(gates: [low, medium]))

        #expect(summary.status == .caveated)
        #expect(summary.topBlockers.isEmpty)
        #expect(summary.topCaveats.map(\.title) == ["Telemetry is stale", "Docs are unknown"])
        #expect(summary.recommendedNextAction == "Refresh telemetry evidence.")
    }

    @Test("defensible report has no blockers or caveats")
    func defensibleReportHasNoBlockersOrCaveats() {
        let summary = ReleaseTruthDebtBridge().summary(for: TruthDebtReport(gates: []))

        #expect(summary.status == .defensible)
        #expect(summary.topBlockers.isEmpty)
        #expect(summary.topCaveats.isEmpty)
        #expect(summary.recommendedNextAction == "No truth debt action is required; keep release evidence current.")
    }

    @Test("negative top limit suppresses surfaced lists without hiding next action")
    func negativeTopLimitSuppressesListsWithoutHidingNextAction() {
        let blocker = gate(
            kind: .failedVerification,
            severity: .critical,
            area: "Build",
            title: "Build failed",
            recommendedAction: "Fix the build.",
            blocksReleaseClaim: true
        )

        let summary = ReleaseTruthDebtBridge().summary(
            for: TruthDebtReport(gates: [blocker]),
            topLimit: -1
        )

        #expect(summary.status == .blocked)
        #expect(summary.topBlockers.isEmpty)
        #expect(summary.topCaveats.isEmpty)
        #expect(summary.recommendedNextAction == "Fix the build.")
    }

    private func gate(
        kind: TruthDebtKind,
        severity: TruthDebtSeverity,
        area: String,
        title: String,
        recommendedAction: String,
        blocksReleaseClaim: Bool
    ) -> TruthDebtGate {
        TruthDebtGate(
            kind: kind,
            severity: severity,
            area: area,
            title: title,
            detail: "\(title) detail",
            recommendedAction: recommendedAction,
            blocksReleaseClaim: blocksReleaseClaim,
            sourceIdentifiers: ["\(area)-source"]
        )
    }
}
