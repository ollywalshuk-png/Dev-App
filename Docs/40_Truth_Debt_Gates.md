# Truth Debt Gates

Date: 2026-06-12

Status: implemented core release-claim evaluation, plus documentation. This
document explains the merged `TruthDebtEngine` / `TruthDebtReport` concept. It
does not claim persistence, command running, or release automation. UI surfaces,
where present, must remain read-only presentations of this same report.

## Purpose

Truth Debt gates answer a narrow question:

> Given the local records LocalForge already has, what prevents this project
> from making a defensible release-ready claim?

The engine reads a `RepoSnapshot`, evidence records, risks, and assumptions,
then returns a sorted `TruthDebtReport`. The report contains gates with:

- kind;
- severity;
- verification area, when relevant;
- human-readable title and detail;
- recommended action;
- whether the gate blocks a release-ready claim;
- source record identifiers where a source record exists.

The report status is:

- `Blocked` when any gate blocks a release-ready claim.
- `Caveated` when only non-blocking debt remains.
- `Defensible` when no gates are detected for the current records.

## Gate Types

Merged code recognises these Truth Debt kinds:

- Missing Mission.
- Missing Evidence.
- Unverified Area.
- Failed Verification.
- Stale Verification.
- Blocked Dependency.
- Release-Blocking Risk.
- Active Assumption.
- Contradictory Evidence.

Critical and High in-scope verification debt blocks release-ready claims.
Medium and Low debt can remain as caveats unless tied to a release-blocking
risk or other blocking condition.

Strong evidence means `Observed`, `Measured`, or `Verified` evidence. Assumed,
inferred, or unknown evidence must not be treated as strong proof.

## What It Does Not Claim

Truth Debt gates are not a second Truth Centre score. They do not compute,
replace, or directly adjust the Reality percentage.

They also do not claim:

- persisted Truth Debt records;
- automatic release approval;
- CI, notarisation, signing, or App Store readiness;
- automatic command execution;
- automatic fixes, commits, pushes, merges, or history rewrites;
- background scanning or whole-disk monitoring;
- cloud validation or telemetry;
- proof that the software is safe to ship in the real world.

The gates are a local, read-only evaluation of LocalForge records. Human
validation, release engineering, and any external checks remain separate.

## Relationship To Truth Centre

Truth Centre owns the percentage and the provenance surfaces:

- Reality percentage: the current project-state summary.
- Confidence: how well the known state is backed by evidence.
- Register Health: where evidence, risks, decisions, architecture, and
  assumptions are thin.
- Contribution provenance: source rows explaining material score inputs.

Truth Debt gates are a release-claim guardrail around those surfaces. A high
Reality percentage should not be described as release-ready while blocking
Truth Debt remains. A low percentage with no blocking gates still does not mean
the project is good; it only means the current gate report did not find a
Critical or High blocker in the supplied records.

UI or handoff work may show Truth Debt next to the Truth Centre, but it must
keep the distinction clear:

- the percentage says what the current records summarise;
- provenance says which records explain the percentage;
- gates say which unresolved debts block or caveat release-ready language.

Future Truth Audit Packets are the expected handoff shape for this relationship.
See `Docs/41_Truth_Audit_Packets.md`. Until packet runtime code and tests exist,
that document is direction only, not an implemented export feature.

## Release Language Contract

Truth Debt gates constrain words, not just UI state:

| Truth Debt status | Release wording |
| --- | --- |
| `Blocked` | Say blocked or not release-ready. Name the Critical/High gate and the source record when available. |
| `Caveated` | Say caveated for the stated scope. Name the missing, stale, weak, or unresolved evidence. |
| `Defensible` | Say defensible from local records only if Confidence and provenance also support it. External release checks still need evidence. |

Do not let a high Reality score override this language. Do not imply CI,
signing, notarisation, stapling, Gatekeeper acceptance, App Store readiness,
upstream merge state, or Metal/background-rendering changes unless those facts
are present in upstream `main` or in recorded validation evidence.

## Relationship To Release Readiness

Release Readiness already evaluates in-scope verification areas, stale trust,
dependencies, and release-blocking risks into a board status.

Truth Debt gates complement that board by adding release-claim scrutiny around
missing mission context, missing strong evidence, active assumptions, and
contradictory evidence. They should be used as an additional explanation layer,
not as a replacement for the board.

If a future feature combines the two, preserve these meanings:

- Release Readiness is the board view of verification area state.
- Truth Debt is the record-level reason a release-ready claim is blocked or
  caveated.
- Critical and High blockers must stay visible before any optimistic release
  language.

## Future Agent Preservation Rules

Preserve these rules when modifying or surfacing Truth Debt:

- Keep evaluation local, selected-project-scoped, and read-only.
- Do not add background scans, hidden commands, repository mutation, or network
  checks as part of Truth Debt evaluation.
- Do not turn a recommendation, approval state, or gate action into permission
  to change source files.
- Do not hide missing, stale, failed, unknown, contradictory, or assumption-based
  debt behind a good-looking percentage.
- Keep Critical and High in-scope debt blocking release-ready claims.
- Keep lower-priority debt as caveats unless it is tied to a blocking risk or
  other blocking condition.
- Keep source identifiers for gates wherever a source record exists.
- Use redacted, record-level provenance only; do not persist secrets or command
  output values that would violate existing redaction boundaries.
- Keep output deterministic and sorted with blockers before caveats.
- Update `TruthDebtGateTests` when changing gate semantics.
- Do not describe Truth Debt as release-grade until the stress gates in
  `Docs/36_Truth_Centre_Stress_Plan.md` are satisfied and validated.
