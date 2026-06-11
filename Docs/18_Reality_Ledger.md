# Reality Ledger

Verified in code:

- `LocalForgeCore` has scanner/report/Guardian/command safety foundations.
- `LocalForgeCore` has UserDefaults-backed workspace persistence and security-scoped bookmark resolution foundations.
- `LocalForgeApp` is a SwiftUI macOS app shell.
- `localforge` is a read-only CLI wrapper.
- Phase 2: `ProjectClassifier` (subtypes), `MissionProfileEngine`, `ApplicabilityEngine`, and `RealityEngine` are implemented; the dashboard leads with a Command Centre; output verified via CLI on this repo (recognised as SwiftUI App, reality 51%, next action "Run a build and confirm it succeeds").

How the Reality Engine stays honest:

- Reality score is capped below 100 until something carries Verified-grade evidence; floored at 5.
- The verification chain marks only `Implemented` as reached (source observed); `Observed`/`Verified` are Not Reached; `Built`→`Tested` are Unknown because LocalForge does not build or run the project in this phase.
- Mission and refined identity are surfaced as Inferred/Assumed, never Verified.
- Project setup and verification timeline now let the user replace inference with observed human-entered mission and verification evidence.
- Knowledge Vault known-issue notes are included as Reality risks.
- Phase 6–7: verification trust decays with age (`VerificationAge`); Observed/Measured/Verified evidence keeps a stale Verified record's trust high; open Critical/High risks dock the score; ≥3 active assumptions are surfaced as a limit on Reality.
- Phase 7.5: the score is now **explainable** — `TruthEngine.breakdown` itemises every +/− contribution; and **Confidence** is reported separately from Reality (state of the project vs quality of the evidence behind that state). Unknown-classified evidence never increases either.

Unknown or incomplete:

- Build state (LocalForge does not build the project) — the engine reports this as a known unknown.
- Deep build intelligence, deep security scanning, FSEvents, SQLite, production packaging.
- Phase 3 shipped user-confirmable mission and per-area verification tracking; the Reality Engine now derives known/verified/unverified/failed from real user-entered records, not just heuristics.
- Phase 4 shipped setup wizard, verification timeline metadata, and local knowledge notes. Editing/deleting notes is not yet implemented.
- Deep identity from pbxproj target/scheme/platform parsing (current detection is marker- and source-signal based).
