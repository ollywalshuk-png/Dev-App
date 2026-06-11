import Foundation

public struct CodeBloatScannerEngine: Sendable {
    public static let defaultLineThreshold = 1_750

    public var lineThreshold: Int

    public init(lineThreshold: Int = Self.defaultLineThreshold) {
        self.lineThreshold = lineThreshold
    }

    public func scan(repoRoot: URL) -> [CodeSizeFinding] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: repoRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        guard let enumerator = fm.enumerator(
            at: repoRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var findings: [CodeSizeFinding] = []
        for case let url as URL in enumerator {
            if shouldSkip(url: url, repoRoot: repoRoot) {
                enumerator.skipDescendants()
                continue
            }
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }

            let lines = countLines(in: url)
            guard lines > lineThreshold else { continue }
            findings.append(CodeSizeFinding(
                path: url.path,
                relativePath: relativePath(for: url, root: repoRoot),
                lineCount: lines,
                threshold: lineThreshold,
                language: languageName(for: url.pathExtension)
            ))
        }

        return findings.sorted {
            if $0.lineCount == $1.lineCount { return $0.relativePath < $1.relativePath }
            return $0.lineCount > $1.lineCount
        }
    }

    public func recommendations(from findings: [CodeSizeFinding]) -> [RecommendationRecord] {
        findings.map { finding in
            RecommendationRecord(
                category: .codeSize,
                title: finding.recommendationTitle,
                summary: "\(finding.relativePath) has \(finding.lineCount) lines of code, above the \(finding.threshold)-line review threshold.",
                targetPath: finding.path,
                sourceFilesAffected: true,
                severity: severity(for: finding),
                confidence: 1,
                evidenceSummary: "Repo-scoped code-size scan counted \(finding.lineCount) lines in a \(finding.language) source file.",
                impact: "Very large source files are harder to review, test, navigate, and safely modify. They often hide multiple responsibilities in one place.",
                suggestedAdjustment: "Review the file for separable responsibilities. Prefer extracting focused views, services, helpers, or test fixtures manually with tests around the behaviour.",
                safetyWarning: "This recommendation concerns a source file. Any refactor can break behaviour and must be approved separately with a clear diff before execution.",
                rollbackNote: "Use version control or create a backup before refactoring. LocalForge does not split or rewrite this file automatically in V1.6."
            )
        }
    }

    private var supportedExtensions: Set<String> {
        ["swift", "m", "mm", "h", "hpp", "cpp", "c", "js", "ts", "tsx", "jsx", "py", "rs", "go", "kt", "java"]
    }

    private var excludedNames: Set<String> {
        [".git", ".build", ".swiftpm", "DerivedData", "node_modules", "Pods", "Carthage", ".cache", "dist", "build"]
    }

    private func shouldSkip(url: URL, repoRoot: URL) -> Bool {
        guard url.path != repoRoot.path else { return false }
        return excludedNames.contains(url.lastPathComponent)
    }

    private func countLines(in url: URL) -> Int {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return 0 }
        var count = 0
        for byte in data where byte == 10 {
            count += 1
        }
        if data.last != 10 { count += 1 }
        return count
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func languageName(for ext: String) -> String {
        switch ext.lowercased() {
        case "swift": "Swift"
        case "m", "mm", "h", "hpp", "cpp", "c": "C/Objective-C/C++"
        case "js", "ts", "tsx", "jsx": "JavaScript/TypeScript"
        case "py": "Python"
        case "rs": "Rust"
        case "go": "Go"
        case "kt": "Kotlin"
        case "java": "Java"
        default: ext.uppercased()
        }
    }

    private func severity(for finding: CodeSizeFinding) -> RecommendationSeverity {
        if finding.lineCount >= finding.threshold * 3 { return .critical }
        if finding.lineCount >= finding.threshold * 2 { return .high }
        return .warning
    }
}
