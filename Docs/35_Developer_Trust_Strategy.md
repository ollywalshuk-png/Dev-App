# Developer Trust Strategy

Date: 2026-06-12

Status: product strategy and review guide. This document does not claim new
runtime capability.

## Market Position

LocalForge should compete as a developer trust tool, not as a generic IDE,
CI runner, dashboard, or auto-fix assistant.

The core promise is:

> LocalForge tells a developer how much they can trust a project right now,
> why that percentage is defensible, and what evidence would move it.

That means the product must stay boring in the places where trust is earned:
local-first storage, explicit project selection, explainable scoring, stable
records, bounded command execution, and no hidden mutation of user repositories.

## Truth Centre Contract

Truth Centre is the primary percentage and provenance surface.

The percentage must never be a decorative health score. It must be a short
summary of records the user can inspect:

- Mission and project identity.
- Verification records.
- Evidence records and linked files.
- Build history.
- Test records.
- Environment snapshots.
- Git state.
- Risks, assumptions, decisions, and architecture records.
- Journal entries where they explain state changes.

Every movement in the percentage should answer four questions:

- What changed?
- Which record proves it?
- How fresh is the proof?
- What would improve or reduce the score next?

## Audit Handoff Direction

The next trust surface should be an auditable handoff, not a louder score.
`Docs/41_Truth_Audit_Packets.md` defines that direction as a future packet
contract.

The packet should keep five signals separate:

- Reality score: current local project-state summary.
- Confidence: how well that state is supported by fresh, strong evidence.
- Contribution provenance: the source rows that explain material score inputs.
- Truth Debt gates: blockers and caveats that constrain release-ready language.
- Release Readiness wording: the human claim allowed by the weakest supported
  signal.

No percentage alone should authorize release optimism. If provenance is thin,
Confidence should fall or the handoff should say what is missing. If Critical or
High in-scope Truth Debt remains, release-ready language stays blocked even
when the Reality score looks strong. If external checks such as CI, signing,
notarisation, stapling, Gatekeeper, or upstream merge state are not evidenced,
the packet must say so.

## Product Principles

- Percentage first, provenance immediately beside it.
- Unknown is not neutral; unknown should reduce confidence or readiness.
- Verified without evidence is weaker than verified with evidence.
- Fresh measured evidence should outrank old notes.
- Failed or blocked dependencies must be visible before release optimism.
- Risk is part of truth, not a separate afterthought.
- User intent is not execution permission.
- Local records are the source of truth; cloud services are not required.
- Scope stays selected-project bounded unless the user explicitly expands it.
- The product should prefer "not enough evidence" over invented certainty.

## Competitive Bar

LocalForge starts to look market-grade when a developer can open a repo and
quickly see:

- The current trust percentage.
- The exact records behind that percentage.
- The release blockers and stale claims.
- The fastest evidence item that would improve confidence.
- The latest build/test/environment signals.
- A copyable handoff that another developer can audit.
- A clear safety boundary: what LocalForge will observe, recommend, and never
  do without approval.

## Practical Roadmap Shape

Ship small slices that make the existing truth workflow more defensible:

1. Clarify the Truth Centre explanation around score, confidence, freshness,
   risks, and unknowns.
2. Add deterministic stress fixtures for the Truth calculation.
3. Add provenance rows for every material score contribution.
4. Add regression tests for stale evidence, blocked dependencies, conflicting
   records, and release-blocking risks.
5. Add manual validation scripts or checklists for large workspaces and old
   workspace migrations.
6. Only then consider smarter recommendations, and keep them approval-gated.

## Anti-Goals

Do not make LocalForge look stronger by making it less trustworthy.

Avoid:

- Opaque AI scoring.
- Cloud telemetry.
- Background whole-disk scanning.
- Automatic fixes.
- Automatic commits, pushes, merges, or branch rewrites.
- Treating recommendation approval as permission to mutate source.
- Counting unverified manual notes as strong proof.
- Hiding stale, failed, or contradictory records behind a good-looking score.

## Review Standard

A PR improves developer trust if it makes at least one of these easier:

- Prove where the percentage came from.
- Reproduce the percentage from fixture data.
- Explain why a project is blocked or risky.
- Reduce hidden assumptions.
- Improve user control over risky actions.
- Preserve local-first, selected-project-scoped operation.

A PR does not improve developer trust if it mainly adds surface area without
better evidence, provenance, accuracy, or safety.
