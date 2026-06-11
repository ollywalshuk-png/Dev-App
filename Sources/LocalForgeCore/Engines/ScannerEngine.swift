import Foundation

public struct ScannerEngine: Sendable {
    private let classifier = ProjectClassifier()
    private let gitEngine = GitEngine()
    private let missionEngine = MissionProfileEngine()
    private let applicabilityEngine = ApplicabilityEngine()
    private let realityEngine = RealityEngine()

    public init() {}

    public func scan(_ context: ProjectContext) async throws -> RepoSnapshot {
        guard context.permission.state == .approved else {
            return RepoSnapshot(
                project: context,
                permissionState: context.permission.state,
                scanPolicy: context.scanPolicy,
                summary: RepoSummary(),
                findings: [
                    Finding(
                        title: "Repository access unavailable",
                        detail: context.permission.description,
                        severity: .warning,
                        category: .privacy,
                        evidenceClassification: .observed
                    )
                ],
                evidence: [],
                isReadOnly: true
            )
        }

        let summary = collectSummary(at: context.rootURL)
        let identity = classifier.classify(rootURL: context.rootURL)
        let mission = missionEngine.profile(identity: identity, rootURL: context.rootURL, projectName: context.name)
        let applicability = applicabilityEngine.items(for: identity, mission: mission)
        let git = gitEngine.status(at: context.rootURL)

        var evidence = [
            Evidence(
                title: "Approved repository scope",
                detail: context.rootURL.path,
                classification: .observed,
                source: "NSOpenPanel/security scope"
            ),
            Evidence(
                title: "Read-only scan policy",
                detail: "Scanner only enumerated metadata and did not mutate files.",
                classification: .observed,
                source: "ScannerEngine"
            )
        ]

        var findings = [
            Finding(
                title: "Local-first privacy posture",
                detail: "No telemetry, cloud AI, source upload, or external API is enabled by default.",
                severity: .info,
                category: .privacy,
                evidenceClassification: .observed
            )
        ]

        // Project recognition — what is this actually?
        evidence.append(
            Evidence(
                title: "Detected project type: \(identity.kind.rawValue)",
                detail: identity.markers.isEmpty ? identity.detail : "\(identity.detail) Markers: \(identity.markers.joined(separator: ", "))",
                classification: identity.confidence,
                source: "ProjectClassifier"
            )
        )
        if identity.kind == .unidentified {
            findings.append(
                Finding(
                    title: "Project type not recognised",
                    detail: identity.detail,
                    severity: .info,
                    category: .workspaceIntegrity,
                    evidenceClassification: .unknown
                )
            )
        }

        if summary.sourceFiles == 0 {
            findings.append(
                Finding(
                    title: "No source files observed",
                    detail: "The selected folder may not be a project root.",
                    severity: .warning,
                    category: .workspaceIntegrity,
                    evidenceClassification: .observed
                )
            )
        }

        if summary.largeFiles > 0 {
            findings.append(
                Finding(
                    title: "Large files observed",
                    detail: "\(summary.largeFiles) files are larger than 25 MB and may need bloat review.",
                    severity: .warning,
                    category: .repository,
                    evidenceClassification: .measured
                )
            )
            evidence.append(
                Evidence(
                    title: "Large file count",
                    detail: "\(summary.largeFiles) files exceed the default large-file threshold.",
                    classification: .measured,
                    source: "ScannerEngine"
                )
            )
        }

        appendGitIntelligence(git, into: &findings, evidence: &evidence)

        let reality = realityEngine.assess(
            identity: identity,
            mission: mission,
            applicability: applicability,
            git: git,
            summary: summary,
            findings: findings,
            evidence: evidence
        )

        return RepoSnapshot(
            project: context,
            permissionState: context.permission.state,
            scanPolicy: context.scanPolicy,
            identity: identity,
            mission: mission,
            applicability: applicability,
            reality: reality,
            git: git,
            summary: summary,
            findings: findings,
            evidence: evidence,
            isReadOnly: true
        )
    }

    private func appendGitIntelligence(
        _ git: GitStatus,
        into findings: inout [Finding],
        evidence: inout [Evidence]
    ) {
        guard git.isRepository else {
            findings.append(
                Finding(
                    title: "Not a Git repository",
                    detail: git.note ?? "No Git working tree was observed at the selected root.",
                    severity: .info,
                    category: .repository,
                    evidenceClassification: .observed
                )
            )
            return
        }

        evidence.append(
            Evidence(
                title: "Git branch: \(git.branchDisplay)",
                detail: {
                    if let hash = git.lastCommitShortHash, let subject = git.lastCommitSubject {
                        let rel = git.lastCommitRelative.map { " (\($0))" } ?? ""
                        return "Last commit \(hash)\(rel): \(subject)"
                    }
                    return git.workingTreeSummary
                }(),
                classification: .observed,
                source: "GitEngine (read-only)"
            )
        )

        if git.isDetached {
            findings.append(
                Finding(
                    title: "Detached HEAD",
                    detail: "HEAD is not on a branch. Commits made now can be lost. Confirm this is intentional.",
                    severity: .warning,
                    category: .repository,
                    evidenceClassification: .observed
                )
            )
        }

        if !git.isClean {
            findings.append(
                Finding(
                    title: "Uncommitted changes",
                    detail: git.workingTreeSummary + ". This is observation only — LocalForge will not modify the working tree.",
                    severity: .info,
                    category: .repository,
                    evidenceClassification: .measured
                )
            )
        }

        if git.hasUpstream, git.behind > 0 {
            findings.append(
                Finding(
                    title: "Behind upstream",
                    detail: "The branch is \(git.behind) commit\(git.behind == 1 ? "" : "s") behind its upstream.",
                    severity: .info,
                    category: .repository,
                    evidenceClassification: .measured
                )
            )
        }
    }

    private func collectSummary(at rootURL: URL) -> RepoSummary {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return RepoSummary()
        }

        var summary = RepoSummary()
        for case let fileURL as URL in enumerator {
            guard shouldCount(fileURL) else { continue }
            guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  values.isRegularFile == true else {
                continue
            }

            summary.totalFiles += 1
            if fileURL.isSourceFile {
                summary.sourceFiles += 1
            }
            if fileURL.isTestFile {
                summary.testFiles += 1
            }
            if fileURL.isDocumentationFile {
                summary.documentationFiles += 1
            }
            if (values.fileSize ?? 0) > 25 * 1_024 * 1_024 {
                summary.largeFiles += 1
            }
        }

        return summary
    }

    private func shouldCount(_ url: URL) -> Bool {
        let ignored = [".build", "DerivedData", "node_modules", ".git"]
        return !url.pathComponents.contains { ignored.contains($0) }
    }
}

private extension URL {
    var isSourceFile: Bool {
        ["swift", "m", "mm", "h", "c", "cpp", "js", "ts", "tsx", "jsx", "py", "rs", "go"].contains(pathExtension.lowercased())
    }

    var isTestFile: Bool {
        lastPathComponent.localizedCaseInsensitiveContains("test")
            || pathComponents.contains("Tests")
    }

    var isDocumentationFile: Bool {
        ["md", "markdown", "txt", "rst"].contains(pathExtension.lowercased())
    }
}
