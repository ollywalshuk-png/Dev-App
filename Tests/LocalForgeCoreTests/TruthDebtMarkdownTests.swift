import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth debt markdown")
struct TruthDebtMarkdownTests {
    @Test("markdown export includes release handoff fields and redacts sensitive text")
    func markdownExportIncludesReleaseHandoffFieldsAndRedacts() {
        let report = TruthDebtReport(gates: [
            TruthDebtGate(
                kind: .unverifiedArea,
                severity: .low,
                area: "Docs",
                title: "Docs not confirmed",
                detail: "Docs handoff is pending.",
                recommendedAction: "Confirm docs before final handoff.",
                blocksReleaseClaim: false,
                sourceIdentifiers: ["33333333-3333-3333-3333-333333333333"]
            ),
            TruthDebtGate(
                kind: .releaseBlockingRisk,
                severity: .critical,
                area: "Signing",
                title: "Notarisation uses api_key=abcdef123",
                detail: "Private note at /Users/example/private/signing.md should not leak.",
                recommendedAction: "Rotate password=supersecret before claiming release-ready.",
                blocksReleaseClaim: true,
                sourceIdentifiers: [
                    "/Users/example/private/source.json",
                    "11111111-1111-1111-1111-111111111111"
                ]
            ),
            TruthDebtGate(
                kind: .activeAssumption,
                severity: .high,
                area: "Mission",
                title: "Signing profile was assumed",
                detail: """
                GitHub token ghp_1234567890abcdefghijklmnopqrstuvwx was pasted into the note.
                -----BEGIN PRIVATE KEY-----
                sensitive
                -----END PRIVATE KEY-----
                """,
                recommendedAction: "Replace the assumption with observed signing evidence.",
                blocksReleaseClaim: true,
                sourceIdentifiers: ["22222222-2222-2222-2222-222222222222"]
            )
        ])

        let markdown = report.markdownExport(topGateLimit: 2, actionLimit: 2)

        #expect(markdown.contains("# Truth Debt Export"))
        #expect(markdown.contains("- Status: Blocked"))
        #expect(markdown.contains("- Headline: 2 truth debt gate(s) block a release-ready claim."))
        #expect(markdown.contains("- Blockers: 2"))
        #expect(markdown.contains("- Caveats: 1"))
        #expect(markdown.contains("- Total gates: 3"))
        #expect(markdown.contains("## Top Gates"))
        #expect(markdown.contains("1. **Critical** Notarisation uses [REDACTED_SECRET] - Signing"))
        #expect(markdown.contains("   - Kind: Release-Blocking Risk"))
        #expect(markdown.contains("   - Blocks release claim: Yes"))
        #expect(markdown.contains("   - Source IDs: 11111111-1111-1111-1111-111111111111, [REDACTED_PRIVATE_PATH]"))
        #expect(markdown.contains("## Actions"))
        #expect(markdown.contains("1. Rotate [REDACTED_SECRET] before claiming release-ready."))
        #expect(markdown.contains("2. Replace the assumption with observed signing evidence."))
        #expect(markdown.contains("[REDACTED_SECRET]"))
        #expect(markdown.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(!markdown.contains("api_key=abcdef123"))
        #expect(!markdown.contains("supersecret"))
        #expect(!markdown.contains("ghp_1234567890abcdefghijklmnopqrstuvwx"))
        #expect(!markdown.contains("BEGIN PRIVATE KEY"))
        #expect(!markdown.contains("/Users/example/private"))
        #expect(!markdown.contains("Docs handoff is pending."))
    }

    @Test("markdown export is deterministic regardless of gate input order")
    func markdownExportIsDeterministic() {
        let gates = [
            TruthDebtGate(
                kind: .missingEvidence,
                severity: .high,
                area: "Build",
                title: "Build is verified without strong evidence",
                detail: "Verified state has no strong evidence.",
                recommendedAction: "Attach measured build evidence.",
                blocksReleaseClaim: true,
                sourceIdentifiers: ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
            ),
            TruthDebtGate(
                kind: .failedVerification,
                severity: .critical,
                area: "Archive",
                title: "Archive is failed",
                detail: "Archive failed.",
                recommendedAction: "Resolve archive failure.",
                blocksReleaseClaim: true,
                sourceIdentifiers: ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
            ),
            TruthDebtGate(
                kind: .unverifiedArea,
                severity: .low,
                area: "Docs",
                title: "Docs is unknown",
                detail: "Docs are unverified.",
                recommendedAction: "Verify docs.",
                blocksReleaseClaim: false,
                sourceIdentifiers: ["cccccccc-cccc-cccc-cccc-cccccccccccc"]
            )
        ]

        let forward = TruthDebtReport(gates: gates).markdownExport()
        let reversed = TruthDebtReport(gates: gates.reversed()).markdownExport()

        #expect(forward == reversed)
        #expect(forward.contains("1. **Critical** Archive is failed - Archive"))
        #expect(forward.contains("2. **High** Build is verified without strong evidence - Build"))
        #expect(forward.contains("3. **Low** Docs is unknown - Docs"))
    }

    @Test("markdown export handles defensible reports")
    func markdownExportHandlesDefensibleReports() {
        let markdown = TruthDebtReport(gates: []).markdownExport()

        #expect(markdown.contains("- Status: Defensible"))
        #expect(markdown.contains("- Headline: No truth debt gates detected for the current records."))
        #expect(markdown.contains("- Blockers: 0"))
        #expect(markdown.contains("- Caveats: 0"))
        #expect(markdown.contains("- Total gates: 0"))
        #expect(markdown.contains("## Top Gates\n- None"))
        #expect(markdown.contains("## Actions\n- None"))
    }
}
