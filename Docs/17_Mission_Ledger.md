# Mission Ledger

Mission: reduce uncertainty across local software projects by reporting observed, measured, verified, inferred, assumed, or unknown truth.

V1 mission focus: establish the shared core, read-only workflow, GUI control room, CLI parity, and governance docs.

## Phase 2 (2026-06-07): from repo viewer to command centre

The product pivoted from answering "is this repo healthy?" (Product A) to "what is actually true about this software, and what should happen next?" (Product C). New engines, all read-only and dependency-free:

- `MissionProfileEngine` — infers what a project is trying to be (instrument, effect, application, developer tool, library, …) from type + name + README. Low-confidence by design (Inferred/Assumed).
- `ApplicabilityEngine` — per-kind in-scope matrix so irrelevant checks (e.g. AU validation on a document app) are marked Not Applicable.
- `RealityEngine` — Known / Verified / Unverified / Assumed / Unknown buckets, top risks, next recommended action, a reality score (never 100 until something is Verified), and a verification chain.

The Workspace dashboard now leads with a Command Centre (Current Project · Type · Mission · State · Reality Score · Verification Status · Top Risks · Next Action). The Guardian is mission-aware. Classification refined into SwiftUI/AppKit/UIKit App, AUv3 Instrument vs Effect, Framework, CLI Tool, Swift Package.
