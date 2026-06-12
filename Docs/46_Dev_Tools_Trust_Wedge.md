# Dev Tools Trust Wedge

Date: 2026-06-12

Status: concise product direction. This document describes a practical market
wedge for Dev Tools and related trust surfaces. It does not claim new runtime
capability.

## Position

Dev Tools should not compete as a bigger terminal, CI runner, IDE extension, or
security platform. The practical wedge is trust around the selected local
project:

- What does LocalForge know about this repository right now?
- Which local records, command outputs, risks, and release checks support that
  view?
- Which recommendations are grounded in evidence rather than generic advice?
- What is still missing before another developer should trust the handoff?

That keeps the product narrow enough to be believable and useful. The
competitor gap is not "runs every tool". It is "makes the current project state
inspectable, caveated, and handoff-ready without uploading the repository or
taking surprise action".

## Competitor Wedge

Most developer tools optimize for speed, breadth, automation, or collaboration.
LocalForge should optimize for locally inspectable project truth.

The wedge has five parts:

1. Local-first project truth: selected-project records, Git state, build/test
   results, environment snapshots, risks, assumptions, and evidence stay tied to
   the local workspace.
2. Evidence-backed recommendations: recommendations should point to the record,
   scan result, command output, risk, or missing evidence that caused them.
3. Release readiness: readiness language should be constrained by the weakest
   supported signal, including failed checks, stale evidence, critical risks,
   and missing external release proof.
4. Safety: Dev Tools should stay preset-based, selected-project scoped,
   read-only by default, and explicit about anything that requires user
   approval.
5. Handoff trust: copyable handoffs should separate verified facts, assumptions,
   blockers, next checks, and do-not-claim items so the next developer can audit
   the state without trusting a summary.

## Product Direction

Use Dev Tools as an evidence intake surface, not as an automation playground.
Each preset should answer three questions:

- What did the user explicitly choose to run?
- What local evidence record did the run create or update?
- How does the result affect Reality, Confidence, Release Readiness, or Handoff
  wording?

Useful near-term product slices:

- Show the source record behind each material recommendation.
- Mark recommendations as blocked, caveated, or ready based on available
  evidence rather than approval state alone.
- Add a release-readiness explanation that names the exact missing checks.
- Keep command output capture redacted and scoped to the selected repository.
- Make handoff packs include top positive evidence, top blockers, stale claims,
  active assumptions, and the next evidence item to collect.
- Treat failed or missing build/test/environment checks as first-class trust
  signals, not secondary log details.

## Differentiation Rules

Dev Tools work should be judged by whether it makes a project easier to trust,
not by whether it adds another preset.

Strong slices:

- Convert local tool output into source-linked evidence.
- Reduce ambiguity around stale, failed, missing, or contradictory records.
- Make recommendation rationale inspectable before the user approves anything.
- Preserve selected-project boundaries and local-only operation.
- Improve handoff language so another developer can reproduce the reasoning.

Weak slices:

- Add broad command coverage without provenance.
- Add optimistic score copy without showing the records behind it.
- Present approval metadata as permission to mutate a repository.
- Hide uncertainty to make the product feel more complete.
- Describe current local checks as equivalent to CI, notarisation, release
  certification, or security assurance.

## Trust Copy

Good product copy should stay concrete:

- "Recommendation based on failed Swift Test preset from this workspace."
- "Release readiness is blocked because no notarisation or Gatekeeper evidence
  is recorded."
- "Confidence is caveated because the latest passing build is stale."
- "Handoff includes assumptions and missing checks separately from verified
  facts."

Avoid broad claims. Prefer wording that names the evidence, scope, and missing
proof.

## Do Not Claim Yet

Do not claim Dev Tools can:

- replace CI, Xcode, GitHub Actions, XCTest, Swift Testing, or release
  engineering review;
- prove a project is secure, secret-free, production-ready, notarised, or safe
  for customers;
- run arbitrary commands, repair code, commit, push, merge, delete files, rotate
  credentials, or rewrite history;
- provide autonomous AI review or automatic remediation;
- validate upstream release state, App Store acceptance, customer impact, or
  clean-machine behavior unless those checks are separately evidenced.

The durable market claim is smaller and stronger: LocalForge helps developers
turn local project signals into inspectable trust, evidence-backed next steps,
and safer handoffs.
