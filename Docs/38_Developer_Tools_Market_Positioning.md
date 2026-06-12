# Developer Tools Market Positioning

Date: 2026-06-12

Status: product positioning and strategy guide. This document does not claim new
runtime capability.

## Position

LocalForge should be positioned as a local developer-trust console for Apple
software projects.

It is not trying to replace an IDE, CI system, issue tracker, static analyser,
security platform, AI coding assistant, or terminal. Its sharper role is to sit
between the repository and the release decision and answer:

- What do we currently know about this project?
- Which records prove it?
- What is stale, failed, blocked, assumed, or unknown?
- What is the next smallest evidence item that would improve trust?

The Big-Dawg developer-tools strategy should therefore mean "trustable enough
to guide real engineering decisions", not "large feature surface". LocalForge
should differentiate by making the evidence chain inspectable.

## Adjacent Categories

LocalForge is adjacent to these developer-tool categories:

| Category | Typical job | LocalForge stance |
| --- | --- | --- |
| IDEs and editors | Write, navigate, run, and debug code | Complement only; LocalForge records project truth and release readiness. |
| CI and build systems | Execute repeatable builds and tests | Complement only; V1 records manual and preset results but is not CI. |
| Static analysis and security scanners | Detect code, quality, dependency, or secret risks | Narrow foundation only; current scans are local, scoped, and evidence-producing. |
| Project dashboards | Summarise status across workstreams | Competes only where status must be backed by project evidence. |
| AI coding assistants and PR bots | Generate, review, or transform code | Complement only; AI output is evidence or handoff material, not truth. |
| Developer utilities | Run small tools and inspections | Complement only; Dev Tools is preset-only and feeds evidence records. |

This framing avoids a weak "all-in-one dev app" claim. The differentiated
surface is provenance: LocalForge should make a status percentage defensible
because the user can inspect the records behind it.

## Differentiators

- Local-first by default: persisted workspace records, no cloud dependency, no
  telemetry, and no source upload requirement.
- Explicit project selection: scans and command presets stay bounded to the
  approved project or selected target.
- Read-only and approval-gated posture: recommendations record user intent, but
  approval metadata is not execution permission.
- Evidence-led workflow: Mission -> Verification -> Evidence -> Reality ->
  Risk -> Release -> Handoff is the product spine.
- Truth Centre separates project state from evidence quality: Reality and
  Confidence answer different questions.
- Unknowns, stale records, failed verification, active assumptions, and open
  release-blocking risks are product signals, not UI noise to hide.
- Handoffs are copyable and audit-friendly because they carry evidence,
  registers, risks, assumptions, and current state.

## Handoff Trust Boundary

LocalForge's developer-trust position is strongest when handoffs act like
review packets, not unchecked status claims.
`Docs/43_Handoff_Trust_Boundaries.md` defines the operating contract.

A competitive handoff should make a reviewer faster at rejecting or accepting a
claim. It should carry:

- selected project and repository scope;
- branch, base, commit, changed files, and review boundary;
- source record identifiers for the material evidence, risks, assumptions,
  recommendations, Truth Debt gates, and release-readiness items;
- commands or manual checks actually run, with result summaries and dates;
- stale, failed, blocked, unknown, or assumption-based caveats;
- the next evidence item most likely to improve Confidence.

It should not carry broad optimism. A handoff that says "release-ready",
"secure", "merged upstream", "notarised", "CI-passed", or "no secrets" must
include the exact evidence for that phrase. Without that evidence, LocalForge
should provide the weaker and more useful claim: what is locally supported,
what is blocked, and what remains to check.

This is where LocalForge can compete against dashboards and PR bots: it reduces
review ambiguity. The product does not need to replace the tools that write,
build, test, sign, or publish software. It needs to make their outputs
traceable enough that a maintainer can review a small PR slice with clear
trust boundaries.

## Promises Currently True

These are fair claims for the current repository state:

- LocalForge keeps workspace data locally, with SQLite as the default backend
  and UserDefaults retained as fallback/test support.
- It supports explicit repository opening, approved-project persistence,
  security-scoped bookmark status, and visible access warnings.
- It classifies selected projects and captures read-only Git state during
  approved scans.
- It maintains mission, verification, evidence, journal, knowledge, decision,
  architecture, risk, and assumption records.
- Reality scoring is evidence-aware and exposes breakdown-style explanations;
  Confidence is separate from Reality.
- Truth Centre includes workspace truth counts, Evidence Explorer, dependency
  map, register health, confidence, evidence, open-risk, and truth-cover
  surfaces.
- Release Readiness, Build History, Test Registry, Environment Registry,
  Knowledge Vault, Universal Search, Timeline Replay, Backup/export/import, and
  copyable handoff packs exist as local workflow surfaces.
- Dev Tools runs only approved presets such as Swift Build, Swift Test, Git
  Status, Codesign Verify, Gatekeeper Check, and Environment Capture; command
  output feeds existing build, test, evidence, and environment records.
- Recommendations exist as safe-intelligence metadata with approval states.
  The current code-bloat scanner is selected-repository scoped and read-only.
- Local secret scanning exists as a foundation slice: selected-repository
  scoped, local-only, redacted previews, Safety recommendations, and no matched
  credential persistence.

## Claims Not To Make Yet

Do not market LocalForge as:

- release-grade, distribution-ready, Developer ID signed, notarised, or
  clean-machine validated;
- a replacement for Xcode, VS Code, GitHub Actions, XCTest, Swift Testing, or a
  real CI/CD pipeline;
- a full build-intelligence, repo-monitoring, test-discovery, runtime, UI,
  accessibility, dependency, or system-health platform;
- a comprehensive security scanner or proof that a repository contains no
  secrets;
- an AI agent, cloud AI reviewer, autonomous coding assistant, or automatic
  repair tool;
- a free-form terminal, arbitrary command runner, background daemon, polling
  monitor, whole-disk scanner, or cross-repository crawler;
- capable of automatically deleting files, rotating credentials, rewriting
  history, changing source code, splitting files, committing, pushing, merging,
  or opening release submissions.

The stronger positioning is: LocalForge records, explains, and helps improve
developer trust without hiding uncertainty or taking surprise action.

## High-Leverage Next Slices

Prioritise slices that make the percentage more defensible before adding broad
new tool categories:

1. Add provenance rows for every material Truth Centre score contribution:
   record kind, identifier, status, freshness, and contribution reason.
2. Turn the Truth Centre stress plan into deterministic fixtures for empty,
   evidence-rich, notes-only, stale, failed-build, blocked-dependency,
   critical-risk, conflicting-record, legacy-import, and large-workspace cases.
3. Make copyable handoffs include the percentage, confidence label, top positive
   contributors, top penalties, unresolved evidence gaps, validation actually
   run, anti-claims, and the next PR-review path.
4. Complete Phase 10F human validation so product copy can distinguish
   "locally validated" from "planned".
5. Tighten Dev Tools evidence capture around build/test failure provenance
   before expanding preset coverage.
6. Expand Security Intelligence only as local, explicit, redacted,
   selected-repository scans with manual remediation guidance.
7. Add recommendation preview/rollback detail before any future mutating action
   is considered.

## Truth Centre As The Defensible Surface

Truth Centre should become the primary commercial surface because it can turn a
simple percentage into an auditable engineering object.

The surface should make the user see, in one scan:

- the current percentage and confidence label;
- the exact records contributing to the score;
- which proof is fresh measured evidence versus weak manual notes;
- failed verification and blocked dependencies;
- open release-blocking risks and active assumptions;
- stale claims and unknown areas;
- the next evidence item most likely to move the score.

The defensibility rule is strict: if a score movement cannot point to a source
record, LocalForge should lower confidence, mark the area unknown, or expose the
gap. That is the defensible advantage.
