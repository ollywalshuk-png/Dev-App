# Truth Centre Validation Checklist

Date: 2026-06-12

Status: local contributor checklist for trust-related PRs. This is not release
approval, notarisation evidence, or a substitute for recorded CI results.

Run from the repository root before claiming a Truth Centre, Reality,
Confidence, Truth Debt, or Release Readiness PR is ready.

## Preflight

- Start from a clean branch and confirm only intended files are changed.
- Confirm the focused test filters still exist:

  ```bash
  rg -n "struct (TruthStressTests|TruthScaleStressTests|TruthScoreAccuracyTests|TruthDebtGateTests|TruthDebtMarkdownTests|RealityCalibrationEdgeTests|EvidenceProvenanceTests|TruthContributionProvenanceTests|ReleaseTrustTests|ReleaseTruthDebtBridgeTests|WorkspaceDoctorTruthDebtTests|WorkspaceDoctorTrustTests)" Tests/LocalForgeCoreTests
  ```

## Focused Local Commands

Use the Xcode toolchain and the local SwiftPM cache:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH=.build/ModuleCache
```

Truth Centre stress and score confidence:

```bash
swift test --cache-path .build/swiftpm-cache --filter 'TruthStressTests|TruthScaleStressTests|TruthScoreAccuracyTests'
```

Truth Debt gates and release-claim wording:

```bash
swift test --cache-path .build/swiftpm-cache --filter 'TruthDebtGateTests|TruthDebtMarkdownTests|ReleaseTruthDebtBridgeTests'
```

Reality, evidence provenance, and Confidence:

```bash
swift test --cache-path .build/swiftpm-cache --filter 'RealityCalibrationEdgeTests|EvidenceProvenanceTests|TruthContributionProvenanceTests'
```

Release readiness and workspace trust guardrails:

```bash
swift test --cache-path .build/swiftpm-cache --filter 'ReleaseTrustTests|WorkspaceDoctorTruthDebtTests|WorkspaceDoctorTrustTests'
```

If the PR touches shared truth models, evidence classification, persistence,
or release readiness semantics, run the full core suite too:

```bash
swift test --cache-path .build/swiftpm-cache
```

## Adversarial Cases

Before marking the PR ready, check that the changed behavior still fails closed
for these cases:

| Case | Expected pressure |
| --- | --- |
| Duplicate evidence | Repeated verified records must not inflate Reality or Confidence. |
| Stale evidence | Old verification must remain visible as stale or lower confidence until refreshed. |
| Conflicting evidence | Passing and failing evidence for one area must surface a conflict or blocker. |
| Out-of-scope evidence | Evidence outside the selected project or verification scope must not pad the score. |
| Missing evidence links | Risks, assumptions, recommendations, and release claims must name missing support instead of implying proof. |

Add or update a regression test when the PR changes one of these outcomes.

## Ready Claim

A trust-related PR can be called locally validated only when:

- the relevant focused commands pass;
- the full core suite passes when shared semantics changed;
- any skipped command is named with a reason;
- adversarial behavior is covered by existing or updated tests;
- the PR notes record the commands and exact failures, skips, or caveats.

Do not describe the PR as release-ready if Truth Debt is blocked, Confidence is
thin, release evidence is missing, or external checks were not actually run.
