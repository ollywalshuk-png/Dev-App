# Truth Centre Adversarial Playbook

Date: 2026-06-12

Status: practical test playbook. This document defines how to attack the Truth
Centre percentage before calling it release-grade. It does not claim new
runtime capability, CI coverage, signing, notarisation, release automation, or
upstream approval.

## What Release-Grade Developer Trust Means

Release-grade developer trust means Olly can open the Truth Centre and see a
percentage that is:

- deterministic from the selected project records;
- backed by source-linked positive and negative provenance;
- separated from Confidence and release-readiness wording;
- willing to say unknown, stale, conflicted, blocked, or not evidenced;
- unable to turn local optimism into external release claims.

The target is not a high percentage. The target is a defensible percentage that
gets worse, caveated, or blocked when the evidence gets worse.

## How To Run The Stress Pass

For each case below:

1. Build a small fixture project or persisted workspace with the stated records.
2. Capture Reality percentage, Confidence, contribution provenance, Truth Debt
   gates, release wording, and copyable handoff output.
3. Run the same fixture twice and compare output.
4. Treat the case as failed if the percentage rises from irrelevant evidence,
   hides negative proof, drops source identifiers, leaks private data, or allows
   release-ready language without supporting records.

Minimum mechanical gate for doc-only changes:

```sh
git diff --check
```

## Adversarial Cases

| Case | Attack fixture | Pass expectation | Fail expectation |
| --- | --- | --- | --- |
| Contradictory evidence | Same in-scope release area has one fresh passing evidence record and one fresh failing evidence record, for example `Build passes locally` plus `Archive fails reproducibly`. | Conflict is explicit. Confidence drops or is caveated. Provenance lists both source records. Critical or High areas block release-ready language until resolved. If a recency rule exists, newer failure wins over older success. | The passing record cancels the failing record, the percentage remains healthy without a conflict row, source IDs disappear, or the handoff says release-ready. |
| Stale evidence | A previously verified Critical/High area is older than the freshness window, with no fresh measured or verified evidence. | Reality or Confidence weakens. Provenance marks the verification stale or expired. Next action asks for re-verification. Release wording is caveated or blocked for that area. | Old verification is treated like fresh proof, no stale penalty is visible, or the handoff implies current validation. |
| Missing build/test proof | Mission says release-grade developer tool, but Build and Automated Tests are unknown, notes-only, or have no strong evidence. | Percentage stays cautious. Confidence stays low or limited. Build/test gaps appear as top unknowns, Truth Debt gates, or release blockers. Allowed wording says not release-ready or caveated by missing build/test proof. | Low-priority wins such as docs, changelog, or manual notes make the score look healthy, or release wording ignores missing build/test evidence. |
| Scope mismatch | Add verified records and strong evidence for out-of-scope or optional areas while required release areas remain unknown or failed. | Out-of-scope records may appear in history but do not improve release-relevant Reality or readiness. Provenance marks them non-release-relevant. Required unknown or failed areas remain visible. | Marketing, optional, unrelated, or wrong-project evidence increases the release score or hides required-area gaps. |
| Private-data redaction | Evidence body, command output, or linked notes contain tokens, credentials, customer data, signing material, or private local paths. | UI, provenance, packets, and handoffs redact sensitive values while preserving safe metadata: record kind, source identifier, area, timestamp or freshness, status, and reason. Redaction must not delete the negative or positive contribution itself. | Any secret value appears in copied output, logs, packets, screenshots, or committed fixtures; or redaction removes the source row so the percentage can no longer be audited. |
| Release claim overreach | Local records look strong, but there is no recorded CI pass, codesign verification, notarisation, stapling, Gatekeeper result, clean-machine test, upstream merge, or official release publication. | Wording is limited to the evidenced scope, for example defensible from local records. Anti-claims explicitly name missing external checks. Truth Debt stays separate from the percentage. | A high percentage becomes distribution-ready, notarised, CI-green, upstream-merged, customer-safe, or release-approved language without corresponding evidence. |

## Pass Bar

A stress pass is credible only when every case can be reviewed from records, not
from trust in the tester:

- Same input records produce the same percentage, Confidence, gates, and
  provenance ordering.
- Every material score movement has a source kind, identifier or area, status,
  freshness state when relevant, direction, and reason.
- Missing, stale, failed, contradictory, assumption-based, and out-of-scope
  inputs are visible before any optimistic wording.
- Critical or High in-scope blockers prevent release-ready claims.
- External release facts are claimed only when separately evidenced.
- Redacted output is still auditable without exposing private values.

## Operator Rule

When a case fails, do not soften the label. Fix the model, lower the
percentage, lower Confidence, add provenance, add a gate, or narrow the release
wording. A friendly percentage that cannot survive these attacks is not
release-grade developer trust.
