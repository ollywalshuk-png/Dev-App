# LOCALFORGE V1.5 — DEVELOPMENT INTELLIGENCE, QA, VALIDATION & SYSTEM HEALTH EXPANSION

Status: future expansion specification. This document is a roadmap, not a claim that every item below is implemented.

## Mission

LocalForge shall evolve beyond a repository monitor into a comprehensive Apple development intelligence platform capable of analysing:

- Application health
- Repository health
- Build health
- Code quality
- Test quality
- Project architecture
- Dependency integrity
- System health
- Development environment health

The objective is to reduce developer context switching and provide a single local source of truth for project status.

LocalForge remains:

- Local-first
- Privacy-first
- Apple-native
- Read-only by default
- Permission-gated for modifications
- Evidence-driven and explainable

## Current V1 Foundation

Already implemented or partly implemented:

- Workspace Centre: projects, security-scoped bookmarks, selected repositories, missions, phases, project type detection.
- Verification Centre: verification records, statuses, timeline, evidence links.
- Evidence Centre: evidence records for builds, tests, environment captures, utilities, reports, and handoffs.
- Build Centre foundation: manual Build History and Dev Tools build/test evidence capture.
- Test Centre foundation: Test Registry records and linked verification areas.
- Environment Centre foundation: Environment Registry snapshots and comparison.
- Repository Centre foundation: read-only Git state when the selected project is a Git repository.
- Security Centre foundation: signing, Gatekeeper, quarantine, entitlements, notarisation checks through Utility Centre.
- Release Centre foundation: Release Readiness board.
- Agent Centre foundation: handoff/report generation.

Deferred by design:

- Full Build Intelligence
- Full Repo Monitor
- Full automated test runner
- Runtime Intelligence
- UI Intelligence
- AI systems
- Whole-disk scanning
- Automatic fixes
- Automatic repository modification
- Background daemons or polling

## Stable Next Roadmap

Phase 10E consolidates the next capability plan in
`Docs/33_Phase_10E_Roadmap_Release_Baseline.md`. Treat the following as
roadmap, not implementation claims:

- Phase 10F - Manual validation completion.
- Phase 11 - Release engineering.
- Phase 12 - Build intelligence.
- Phase 13 - Repository intelligence.
- Phase 14 - Test intelligence.
- Phase 15 - System / environment health.
- Phase 16 - Security intelligence.
- Phase 17 - Developer toolbox.
- Phase 18 - Apple development centre.
- Phase 19 - Agent centre.
- Phase 20 - Optional local AI layer.

## Developer Intelligence Layer

### Project Structure Analysis

Future analysis should inspect:

- SwiftUI views
- AppKit views
- UIKit views
- Models
- Services
- Managers
- ViewModels
- Coordinators
- Extensions
- Packages
- Frameworks
- Assets
- Resources

Future outputs:

- Project map
- Architecture map
- Dependency graph
- Screen hierarchy
- Data flow map
- Service relationships

Do not build full architecture analysis until the existing Mission -> Verification -> Evidence -> Reality -> Release workflow is stable.

### Code Quality Engine

Future Swift quality checks may detect:

- Dead code
- Unused imports
- Unused variables
- Duplicate code
- Excessive nesting
- Large files
- Large functions
- Naming violations
- Architecture violations

Future outputs:

- Technical debt list
- Risk areas
- Complexity hotspots
- Quality score
- Maintainability score
- Complexity score

This must stay local and read-only unless the operator explicitly approves a change.

### Build Health Engine

Future build health should track:

- Last successful build
- Failed builds
- Build duration
- Build trends
- Warnings
- Errors
- Build regressions
- Build slowdowns
- New warnings
- New errors

Future inputs:

- `swift build`
- `xcodebuild`
- DerivedData
- Build logs
- Signing failures
- Provisioning failures

Existing Build History and Dev Tools evidence capture are the V1 foundation. Do not add a background build runner without explicit product approval.

### Test Intelligence Engine

Future test discovery may identify:

- XCTest
- Swift Testing
- UI Tests
- Integration Tests

Future outputs:

- Test inventory
- Coverage reports
- Missing coverage reports
- Untested files
- Untested screens
- Untested services
- Weak coverage areas
- Coverage heat maps
- Risk maps

Regression detection should compare the current build against previous successful builds and identify new failures, new warnings, missing tests, and behaviour changes.

The current Test Registry is manual and evidence-focused. It is not a full automated test runner.

### Automated QA Layer

Future UI validation may check:

- Layout issues
- Clipping
- Overlapping views
- Hidden controls
- Missing constraints
- Accessibility violations

Future accessibility validation may check:

- WCAG issues
- Dynamic Type support
- Colour contrast
- Keyboard navigation
- VoiceOver compatibility

Future outputs:

- UI validation report
- Accessibility report
- Accessibility score

Do not add automated UI validation until the manual runtime validation workflow is stable.

### Application Health Engine

Future runtime health may track:

- Crashes
- Exceptions
- Memory warnings
- High memory usage
- CPU spikes
- Resource bottlenecks

Future outputs:

- Health score
- Stability score
- Runtime risk list

No runtime daemon exists in V1.

### System Health Engine

Future storage checks:

- Available disk space
- Large folders
- DerivedData size
- Cache growth
- Build artifact growth
- Storage risks
- Build risks caused by low space

Future Xcode health checks:

- Xcode version
- SDK availability
- Simulator health
- Toolchain integrity
- Signing certificates
- Broken toolchains
- Missing SDKs
- Expired certificates

Future development environment checks:

- Git
- Swift
- Xcode
- Command Line Tools
- Homebrew
- Package manager state
- Missing dependencies
- Version mismatches
- Environment conflicts

The Environment Registry and Utility Centre provide the bounded V1 foundation.

### Repository Hygiene Engine

Future repository hygiene may find:

- Large files
- Duplicate files
- Unused assets
- Unused resources
- Stale screenshots
- Temporary files

Future local security scanning may detect:

- API keys
- Secrets
- Tokens
- Certificates
- Private credentials

No cloud transmission is allowed. No whole-disk scanning or auto-delete is allowed.

### Developer Copilot Reports

Future quick summary:

- Build status
- Test status
- Repo status
- Health status
- Green / amber / red summary

Future detailed reports:

- Build
- Testing
- Repository
- Architecture
- Performance
- Security
- Accessibility

Future master context export:

- Project overview: project name, branch, commit, build status.
- Repository state: modified files, new files, deleted files.
- Build analysis: errors, warnings, timing.
- Test analysis: coverage, failures, risk areas.
- Architecture analysis: dependency graph summary, complexity summary.
- Security analysis: potential leaks, risk findings.
- Performance analysis: memory concerns, CPU concerns.
- System analysis: disk health, Xcode health, toolchain health.
- Relevant code context: key files, related files, impacted files.

AI handoff mode may format exports for ChatGPT, Codex, Claude, Cursor, and Gemini, but LocalForge must not add cloud AI or automatic AI execution as part of this roadmap entry.

## Safe Fix Framework

Allowed future workflow:

1. Observe
2. Analyse
3. Explain
4. Recommend
5. Request approval
6. Execute

Never allowed:

1. Observe
2. Execute automatically

Non-goals:

- Auto-commit code
- Auto-push code
- Auto-delete files
- Auto-merge branches
- Auto-modify production code
- Auto-fix without approval

LocalForge remains an intelligence platform first and an automation platform second.

## Developer Tooling Capability Map

These categories organise future LocalForge modules around developer jobs-to-be-done. They are roadmap categories unless already listed as implemented foundation above.

### 1. Workspace Centre

- Projects
- Workspaces
- Repositories
- Bookmarks
- Missions
- Phases
- Tags
- Project type detection
- Multi-project workspaces

### 2. Knowledge Centre

- Decisions
- Architecture notes
- Lessons learned
- Release notes
- Known issues
- AI handoffs
- Technical documentation

### 3. Verification Centre

- Verified
- Failed
- Unknown
- In progress
- Blocked
- Timeline
- Evidence

### 4. Evidence Centre

- Builds
- Tests
- Logs
- Screenshots
- Crash reports
- Instruments captures
- Environment captures
- Utility results
- Manual validation

### 5. Build Centre

- Build history
- Warnings
- Errors
- Artifacts
- Xcode builds
- Swift builds
- Archive builds

### 6. Test Centre

- Swift Testing
- XCTest
- XCUITest
- Manual QA
- Smoke tests
- Validation runs
- Coverage

### 7. Environment Centre

- Xcode versions
- Swift versions
- SDKs
- Simulators
- Certificates
- Toolchain drift

### 8. Repository Centre

- Branches
- Commits
- Tags
- Releases
- Dirty state
- Untracked files
- Large files
- Stale branches
- Dependency drift

### 9. Diagnostics Centre

- Build logs
- Runtime logs
- Crash logs
- Instruments captures
- CPU
- Memory
- Energy

### 10. Security Centre

- Secrets
- API keys
- Tokens
- Certificates
- Dependency checks
- Signing
- Entitlements
- Notarisation
- Gatekeeper

### 11. Release Centre

- Readiness
- Signing
- Notarisation
- TestFlight
- App Store
- Release checklist

### 12. Dev Tools Centre

- JSON
- YAML
- XML
- Markdown
- Regex
- Base64
- URL encoding
- JWT
- UUID
- Hashing
- Timestamps
- Diff viewer
- Colour tools
- Contrast checker

### 13. API Centre

- REST
- GraphQL
- WebSockets
- Mock responses

### 14. Design Centre

- Screenshots
- Reference designs
- Figma references
- Asset inventories
- Colours
- Typography
- Spacing

### 15. Apple Development Centre

- Xcode awareness
- Schemes
- Targets
- Configs
- Swift concurrency
- SwiftUI hierarchy
- AUv3 parameters
- AU validation
- MIDI routing
- TestFlight
- Instruments
- Reality Composer Pro

### 16. Agent Centre

- Codex sessions
- Claude sessions
- ChatGPT sessions
- Cursor sessions
- Prompts
- Outcomes
- Files changed
- Verification result
- Handoffs

## Governance

Before promoting any roadmap item into implementation, ask:

- Does this help answer what is true about the project?
- Does this help decide what should happen next?
- Can it stay local-first and read-only by default?
- Can it be explained to a novice without hiding technical detail?
- Can evidence support the result?

If the answer is no, do not build it yet.
