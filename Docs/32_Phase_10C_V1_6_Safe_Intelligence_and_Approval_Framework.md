# Phase 10C / V1.6 — Safe Intelligence and Approval Framework

Status: implementation scope for the next bounded pass.

## Objective

LocalForge should become more useful as a build tracker, health checker, tester, and developer workstation without becoming dangerous. The app may inspect, explain, recommend, and record evidence. It must not mutate project source, repository history, or workspace state silently.

## Safety Model

Allowed workflow:

1. Observe
2. Explain
3. Recommend
4. Preview
5. Request approval
6. Execute only the approved action
7. Record evidence

Disallowed workflow:

1. Observe
2. Execute automatically

## Approval Rules

Each mutating action requires a specific approval for that action. Approval must show:

- Action type
- Target path
- Whether source files are affected
- What will change
- Why LocalForge recommends it
- Evidence supporting the recommendation
- Risk level
- Backup or rollback note
- Clear warning signage

Approval for one action does not approve future actions.

## V1.6 Implementation Scope

Build now:

- Recommendation records stored per project.
- Approval-state model for recommendations.
- Repository-scoped code-size scanner.
- Source files over 1,750 lines of code are flagged.
- Recommendations explain why the file size matters and suggest a refactor direction.
- Recommendations are reviewable and can be marked acknowledged, approved, rejected, or completed.
- Approval is metadata only in this pass; no automatic code rewrite is executed.
- Evidence records are created for recommendation scans and approval decisions.

Still deferred:

- Automatic code rewriting.
- Automatic file splitting.
- Automatic fixes.
- Auto-commit, auto-push, auto-merge, auto-delete.
- Runtime daemon.
- Background polling.
- Whole-disk scanning.
- Cloud AI or hosted analysis.

## Bloat / Code-Size Scanner

The scanner is selected-repository scoped. It must not inspect the whole disk.

Default threshold:

- 1,750 lines of code.

Excluded paths:

- `.git`
- `.build`
- `.swiftpm`
- `DerivedData`
- `node_modules`
- `Pods`
- `Carthage`
- `.cache`
- `dist`
- `build`

Included source-like extensions:

- `swift`
- `m`
- `mm`
- `h`
- `hpp`
- `cpp`
- `c`
- `js`
- `ts`
- `tsx`
- `jsx`
- `py`
- `rs`
- `go`
- `kt`
- `java`

Output:

- File path.
- Line count.
- Threshold.
- Category.
- Risk explanation.
- Suggested adjustment.

No auto-fix is produced in V1.6.

## Recommendation States

- Open: needs review.
- Acknowledged: user has seen it.
- Approved: user approved the recommendation in principle.
- Rejected: user chose not to act.
- Completed: user has handled it manually or through a future approved action.

Approval state is not execution permission for arbitrary commands. It only records user intent for the named recommendation.

## UI Requirements

The Recommendations screen must show:

- Clear safety signage.
- Read-only scan action.
- Open/approved/rejected/completed counts.
- Recommendation cards with risk, evidence, target path, source-file impact, suggested adjustment, and approval state.
- Explicit buttons for acknowledge, approve, reject, and mark complete.
- No auto-fix button in this pass.

## Testing

Tests should cover:

- Files above 1,750 lines are flagged.
- Files below threshold are not flagged.
- Excluded folders are skipped.
- Recommendation records decode from older workspace JSON.
- Approval state transitions are explicit and persisted.
- No mutating command is produced by the bloat scanner.
