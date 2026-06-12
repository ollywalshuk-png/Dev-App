# Handoff Trust Boundaries

Date: 2026-06-12

Status: operational handoff and PR-review guide. This document does not claim
new runtime capability, packet export, CI integration, release automation, or
external validation.

## Purpose

LocalForge can compete as a developer trust tool when another developer can
review a handoff without trusting the author's optimism.

A useful handoff is not a pitch. It is a bounded claim backed by inspectable
records, validation output, caveats, and next review steps. The receiving
developer should be able to answer:

- What exactly changed or is being claimed?
- Which local records, commands, artifacts, or source links support it?
- What is still unknown, stale, failed, blocked, or assumed?
- Which PR slice or validation step should be reviewed next?

## Handoff Types

Use the smallest handoff type that fits the work:

| Type | Use it for | Required posture |
| --- | --- | --- |
| Status handoff | Current project state, truth score, risks, or open work | Summarise source-linked records and name gaps. |
| PR slice handoff | A focused code or documentation branch | Describe the diff boundary, validation, review target, and residual risk. |
| Release handoff | A candidate artifact, tag, or upstream publish step | Carry checksums, signing/notarisation/Gatekeeper evidence, and explicit caveats. |
| Agent handoff | Work passed from one agent or maintainer to another | State what was done, what was verified, what was not touched, and where to resume. |

Do not mix these into a broad "everything is ready" summary. If a handoff spans
multiple types, split the claims and evidence by type.

## Claims Handoffs May Make

A handoff may claim:

- A local record exists, with its identifier, area, status, and timestamp when
  available.
- A command or manual check was run, with the command, date, environment,
  target, and result.
- A PR slice changes only the files named in its scope, subject to the actual
  diff.
- A recommendation, risk, assumption, or Truth Debt gate exists and has the
  recorded severity or status.
- A local Reality score, Confidence label, Release Readiness state, or Truth
  Debt status is defensible from the cited records.
- A release artifact has a recorded digest or validation result, if the exact
  artifact and command output are included or linked.
- A next step would improve trust, when that step is framed as required
  evidence rather than guaranteed success.

Use claim language that matches the evidence:

| Evidence strength | Safe wording |
| --- | --- |
| Fresh measured, observed, or verified evidence | "Validated locally by..." |
| Source-linked records but incomplete coverage | "Supported for this scope by..." |
| Manual notes, assumptions, or stale evidence | "Caveated by..." or "Needs verification..." |
| Missing source records | "Unknown until..." |
| Critical or High in-scope Truth Debt | "Blocked by..." |

## Claims Handoffs Must Not Make

A handoff must not claim:

- CI, signing, notarisation, stapling, Gatekeeper acceptance, clean-machine
  launch, App Store readiness, or upstream merge state unless that exact check
  is evidenced.
- Release-ready, production-ready, secure, comprehensive, complete, or
  risk-free status while Critical or High in-scope Truth Debt, failed critical
  verification, release-blocking risk, or missing strong evidence remains.
- That a repository has no secrets. Local secret scanning can only claim the
  scoped scan result and redacted findings it actually produced.
- That LocalForge performed background scanning, whole-disk discovery, network
  validation, source mutation, automatic fixes, commits, pushes, merges, or
  history rewrites unless implemented code and validation prove it.
- That recommendation approval is permission to execute arbitrary changes.
- That AI output, generated summaries, or agent notes are truth without source
  records or validation.
- That unmerged branches, fork-only work, or another agent's work are present
  in upstream `main`.
- That omitted files were reviewed, tested, or intentionally unchanged unless
  the reviewer can verify the diff boundary.

When evidence is absent, the correct output is an anti-claim: name the missing
check and the safest weaker phrase.

## Evidence To Carry

Every trust handoff should carry enough material for a reviewer to reproduce
the claim or reject it quickly:

- Project identity and selected repository scope.
- Git branch, base, commit hash, and whether the work is fork-only, upstream,
  or local.
- Changed files and the intended review boundary.
- Source record identifiers for evidence, verification, risks, assumptions,
  decisions, recommendations, Truth Debt gates, and release-readiness items.
- Validation commands actually run, including command text, exit status,
  relevant summary, and date.
- Environment details that affect trust: Xcode path/version, macOS version,
  sandbox or approval limits, selected project path, and artifact path when
  relevant.
- Artifact identifiers such as filenames, bundle identifiers, tag names, and
  SHA-256 digests for release handoffs.
- Known stale records, failed checks, unresolved blockers, active assumptions,
  and unknown areas.
- Redaction note for any logs or evidence that were trimmed to avoid exposing
  credentials, private paths, tokens, signing material, or secret values.
- Next evidence item that would most improve Confidence or unblock release
  wording.

If a handoff cannot include source-linked evidence, it should say so plainly
and lower the claim.

## PR Slice Review

PR slices are how LocalForge earns trust incrementally. A reviewable slice has
one job, a small diff, and a validation story that matches the risk.

Before calling a PR slice ready for review, check:

- Scope: the changed files match the stated task and do not include unrelated
  churn or another agent's work.
- Base: the branch was created from the intended upstream base or the handoff
  explains why not.
- Behavior: user-facing or runtime changes have focused tests or manual
  validation.
- Evidence: any trust, release, security, or readiness claim points to a record,
  command, artifact, or test.
- Boundaries: local-only, selected-project-scoped, read-only, and approval-gated
  rules still hold where relevant.
- Failure mode: stale, failed, blocked, unknown, and assumption-based states are
  visible rather than smoothed into a positive status.
- Review path: the handoff names the exact files, tests, and commands the next
  reviewer should inspect first.

Reject or re-scope a slice when it:

- Adds broad surface area without better evidence, provenance, accuracy, or
  safety.
- Combines unrelated feature work, docs, release operations, and cleanup in one
  branch.
- Describes planned work as implemented behavior.
- Hides weak evidence behind a high percentage, green badge, or optimistic
  summary.
- Requires credentials, cloud access, or mutable repository operations to
  evaluate a local trust claim.

## Competitive Standard

The competitive bar is operational: LocalForge should reduce the time it takes
for a maintainer to decide what can be trusted.

That means each new trust feature should make at least one review action easier:

- find the source record behind a claim;
- reproduce or rerun the validation;
- identify why release-ready language is blocked or caveated;
- see which evidence is stale, missing, failed, or assumed;
- separate local facts from external release checks;
- pass a small, reviewable PR slice to another developer.

If a feature cannot improve one of those review actions, it may still be useful,
but it should not be described as developer trust work.
