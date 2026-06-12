# Truth Centre Confidence Model

Date: 2026-06-12

Status: documentation slice for developer trust and release-grade positioning.
This document explains language and review expectations. It does not claim new
runtime capability, release automation, CI coverage, signing, notarisation, or
upstream approval.

## Purpose

Truth Centre should help Olly and future contributors make careful claims about
a project without turning one percentage into permission to ship.

Keep three signals separate:

- Reality: what the current LocalForge records say about the selected project.
- Confidence: how much trust to place in that Reality summary, based on
  evidence strength, freshness, scope, and contradictions.
- Release Readiness: the human release claim allowed after Reality, Confidence,
  Truth Debt, validation, and external release checks are considered together.

The percentage is useful because it compresses a lot of local records into a
quick read. It is not a release approval. A high percentage can still be
blocked by weak provenance, stale validation, release-blocking risks, failed
dependencies, missing CI/signing/notarisation evidence, or Critical/High
in-scope Truth Debt.

## Practical Meaning

Reality answers: "What does the local record set currently describe?"

Examples:

- Verification areas marked passed or failed.
- Evidence records linked to files, commands, tests, builds, or notes.
- Open risks, active assumptions, decisions, build history, and environment
  snapshots.
- Git state and selected-project identity.

Confidence answers: "How defensible is that description?"

Confidence should rise when evidence is strong, fresh, in-scope, source-linked,
and consistent. Confidence should fall or become caveated when evidence is
missing, manual-only, old, duplicated, out of scope, contradicted, or impossible
to trace back to source records.

Release Readiness answers: "What may we responsibly say now?"

Release Readiness is stricter than Reality and Confidence. It must respect the
weakest supported signal. A project can have a good Reality percentage and
still be "blocked" or "caveated" if validation is incomplete, release gates are
open, or external checks have not been evidenced.

## Adversarial Cases

Use these cases when reviewing scoring, copy, UI, or future packet output.

| Case | Failure mode | Correct response |
| --- | --- | --- |
| Duplicate evidence | The same build log, note, or file is counted as several independent proofs. | Do not inflate Reality or Confidence. Prefer one source row, or mark duplicates as supporting context only. |
| Out-of-scope evidence | Evidence belongs to another repo, branch, target, platform, date range, or release claim. | Exclude it from the claim, or show it as out-of-scope context with no release-ready credit. |
| Contradictory evidence | A newer failed check conflicts with an older passed check, or records disagree about the same area. | Surface the conflict. Prefer newer stronger evidence, lower Confidence, and block/caveat release language when the conflict affects release scope. |
| Stale evidence | Old proof is treated as current even though code, dependencies, environment, or release requirements changed. | Decay Confidence, mark the evidence stale, and require fresh validation before stronger release language. |

These are not edge cases for later polish. They are the cases that determine
whether Truth Centre feels trustworthy to developers.

## Release-Grade Language

Use release-grade wording only when all of these are true for the stated scope:

- Reality is backed by source-linked records, not just manual optimism.
- Confidence is strong because evidence is fresh, in-scope, and consistent.
- Critical and High in-scope Truth Debt gates are absent.
- Release Readiness has no blocking verification, dependency, risk, or
  assumption debt.
- External release claims are separately evidenced, for example CI, signing,
  notarisation, stapling, Gatekeeper, App Store, or upstream merge state.

If any item is missing, the correct language is blocked, caveated, or
not-yet-proven. The percentage can still be displayed, but it must not be used
as approval language.

## Contributor Rules

- Keep Reality, Confidence, and Release Readiness visibly distinct in docs, UI,
  tests, and handoffs.
- Prefer "not enough evidence" over invented certainty.
- Do not let duplicated or unrelated evidence raise a release claim.
- Treat stale and contradictory evidence as confidence problems, not wording
  problems.
- Keep release-ready claims local-record-bound unless external checks are
  actually run and recorded.
- When changing score semantics, update fixtures and docs that explain why the
  number moved.

Truth Centre earns trust by making uncertainty inspectable. A lower, better
explained claim is stronger than a high percentage that hides weak evidence.
