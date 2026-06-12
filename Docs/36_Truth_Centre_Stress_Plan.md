# Truth Centre Stress Plan

Date: 2026-06-12

Status: test and validation plan. This document defines gates for a future
release-grade Truth Centre claim; it does not claim every release-grade stress
gate is already implemented.

Related implemented concept: `TruthDebtEngine` now provides a core,
read-only Truth Debt report for release-ready language. See
`Docs/40_Truth_Debt_Gates.md`. That report is a gate/caveat layer over existing
records; it is not the Truth Centre percentage, not a persistence layer, and not
release automation.

## Objective

Stress the Truth Centre percentage until it is deterministic, explainable, and
hard to accidentally inflate.

The desired outcome is not a perfect score. The desired outcome is a score that
is repeatable, bounded, and backed by provenance that a developer can inspect.

## Non-Negotiable Invariants

- The percentage is always between 0 and 100.
- The same workspace data always produces the same percentage.
- Every material score contribution has a source record.
- Missing data cannot silently count as verified data.
- Stale evidence reduces strength or is called out clearly.
- Failed verification cannot be hidden by unrelated positive evidence.
- Release-blocking risks must be visible in the breakdown.
- Active assumptions must lower confidence until resolved.
- Dependency failures must propagate to dependent verification areas.
- Imported or migrated workspaces must not inflate trust by losing old fields.

## Fixture Matrix

Create deterministic fixtures for these scenarios before making a release-grade
accuracy claim:

| Scenario | Setup | Expected result |
| --- | --- | --- |
| Empty project | Mission exists, no verification or evidence | Low percentage, high unknown count, clear next action |
| Evidence-rich project | Verified areas with fresh measured evidence | High percentage with full provenance rows |
| Notes-only project | Verification marked manually with weak or no evidence | Moderate or limited trust, not release-grade |
| Stale project | Previously strong evidence beyond freshness window | Score or confidence decays and calls out stale proof |
| Failed build | Build verification failed with linked evidence | Build area reduces score and appears as blocker |
| Blocked dependency | Dependent verification area waits on failed prerequisite | Dependent area cannot appear fully trusted |
| Open critical risk | Critical release-blocking risk remains open | Score/readiness reduced and risk shown prominently |
| Conflicting records | Verified status plus newer failed evidence | Newer failed evidence wins or conflict is explicit |
| Imported legacy data | Old workspace decodes through defaults | No crash, no inflated defaults, missing fields visible |
| Large workspace | 1,000+ mixed records across truth types | Calculation remains deterministic and responsive |

## Measurable Gates

Before claiming the Truth Centre is release-grade, require these checks:

- Unit fixtures cover every scenario in the fixture matrix.
- Expected percentages are asserted exactly where the scoring model is
  deterministic.
- Where exact percentages are intentionally not asserted, banded expectations
  are explicit, for example low, limited, moderate, strong.
- 100% of material score rows include record kind, record identifier, status,
  timestamp or freshness state, and contribution reason.
- SQLite round-trip preserves all fields used by the score.
- Legacy decode fixtures prove defaulted fields do not count as strong proof.
- Large workspace scoring finishes in under 250 ms on the release validation
  machine, or the UI shows progress without blocking interaction.
- The breakdown labels every penalty from open risks, failed verification,
  stale evidence, active assumptions, and unknown areas.
- Truth Debt report fixtures distinguish Critical/High blockers from lower
  priority caveats, and preserve source identifiers where source records exist.
- Copyable handoff output includes the percentage, top contributors, top
  penalties, and unresolved evidence gaps.
- Future Truth Audit Packet output includes Reality score, Confidence,
  contribution provenance, Truth Debt gate status, Release Readiness wording,
  and explicit anti-claims for missing external release evidence.
- Manual UI review confirms the percentage, confidence, and provenance remain
  readable in light mode and dark mode.

## Audit Packet Exit Criteria

Before a Truth Audit Packet can support stronger release language, require all
of the following:

- Every material positive score contribution has source provenance.
- Confidence names weak, stale, missing, or assumed evidence instead of hiding
  it behind the Reality percentage.
- Critical and High in-scope Truth Debt gates are absent, or the release claim
  remains blocked.
- Lower-priority debt is listed as a caveat unless another release-blocking
  condition elevates it.
- Release Readiness wording matches the weakest supported signal across
  Reality, Confidence, provenance, Truth Debt, and validation evidence.
- External release checks are cited only when actually run and recorded.

If any item fails, the packet may still be useful as a handoff, but it must not
be described as release-ready.

## Stress Commands

Use the normal validation commands after any scoring or persistence change:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test --cache-path .build/swiftpm-cache
./script/build_and_run.sh --verify
script/notarize.sh --check
```

For this documentation slice, `git diff --check` is the required mechanical
gate.

## Failure Policy

If a fixture exposes an inflated or unexplained percentage, prefer one of these
outcomes:

- Lower the percentage.
- Lower confidence.
- Mark the area unknown.
- Show the conflict.
- Block the release-readiness claim.

Do not hide the issue behind a friendlier label. Truth Centre should earn trust
by being willing to say that the project is not proven yet.

## Implemented Coverage Note

- 2026-06-12: `TruthScaleStressTests` now covers a deterministic 1,200-project
  workspace with 12,000 verification/evidence records, exact aggregate truth
  counts, repeated scoring determinism, related-record resolution, and a
  generous 10-second in-memory upper bound for the scale pass.
- 2026-06-12: `TruthContributionProvenanceTests` now covers structured
  source rows for verified records, failed records, strong evidence, stale
  verification, active assumptions, and open release-blocking risks.
- 2026-06-12: `TruthDebtGateTests` now covers Critical/High truth debt blocking
  release-ready claims, lower-priority truth debt remaining caveated,
  contradictory evidence blocking critical release claims, and failed
  dependencies surfacing as claim blockers.
