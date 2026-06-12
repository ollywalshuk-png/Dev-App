# Truth Audit Packets

Date: 2026-06-12

Status: documentation-only handoff direction. This document describes the next
Truth Centre audit surface LocalForge should move toward. It does not claim an
implemented packet exporter, persistence layer, UI, CI integration,
notarisation, signing, release automation, Metal renderer, background scanner,
or upstream release approval.

## Purpose

A Truth Audit Packet should make a release or handoff claim inspectable without
asking the next agent to trust a summary number.

The packet is a compact, local, read-only evidence index that answers:

- What is the current Reality score?
- How confident is LocalForge in that score?
- Which records materially contributed to the score?
- Which Truth Debt gates block or caveat release-ready language?
- Which release-readiness phrase is allowed by the evidence now?

Until runtime code exists, this is a contract for future docs, UI, tests, and
copyable handoffs rather than an implemented artifact.

## Required Packet Fields

A future packet should include:

- Project identity and selected repository scope.
- Reality score with the score model/version when available.
- Confidence summary with evidence quality, freshness, and unknown-count notes.
- Contribution provenance rows for material positive and negative inputs.
- Truth Debt report status: Blocked, Caveated, or Defensible.
- Release Readiness board status when available.
- Top blockers, top caveats, and the next evidence item that would improve the
  claim.
- Validation commands or manual checks that were actually run, with dates or
  run identifiers where LocalForge stores them.
- Explicit anti-claims for anything not evidenced.

## Language Rules

Reality, Confidence, provenance, Truth Debt, and Release Readiness must not be
collapsed into one optimistic label.

- Reality score says what the current records summarise.
- Confidence says how well the known state is backed by evidence.
- Contribution provenance says which records explain the score movement.
- Truth Debt gates say which unresolved debts block or caveat release-ready
  language.
- Release Readiness language says what a human may responsibly claim next.

Allowed language should follow the weakest supported signal:

| Local state | Allowed release language |
| --- | --- |
| Blocking Truth Debt, failed critical verification, missing strong evidence, or unresolved release-blocking risk | Blocked. Do not call the project release-ready. |
| No blockers, but stale, weak, incomplete, or unreviewed evidence remains | Caveated. Describe the exact scope and missing evidence. |
| Local records are strong, fresh, source-linked, and gate-free | Defensible from local records, still subject to external release checks. |

Even a strong local packet does not prove CI, codesigning, notarisation,
stapling, Gatekeeper acceptance, App Store approval, customer safety, or
upstream merge state unless those checks are separately evidenced.

## Boundaries

Truth Audit Packets must preserve existing LocalForge safety boundaries:

- Selected-project scope only.
- Local records only unless the user explicitly provides or approves external
  evidence.
- Read-only evaluation by default.
- No hidden background scan, daemon, network validation, command execution,
  repository mutation, automatic fix, commit, push, merge, or history rewrite.
- Redacted record-level provenance only; no secrets, tokens, signing material,
  or credential values.
- No claim that Metal/background-rendering work, release PRs, or upstream
  changes are merged unless upstream `main` contains them and validation has
  been recorded.

## Future Agent Checklist

When adding code or docs around audit packets:

- Keep packet generation deterministic from the selected workspace/project
  records.
- Add tests before claiming packet output is reliable.
- Keep source identifiers for every material score row where a source record
  exists.
- Lower confidence or caveat the release phrase when provenance is missing.
- Block release-ready wording when Critical or High in-scope Truth Debt remains.
- Keep external release checks as evidence requirements, not assumptions.
- Update this document, `Docs/36_Truth_Centre_Stress_Plan.md`, and
  `Docs/40_Truth_Debt_Gates.md` when semantics change.
