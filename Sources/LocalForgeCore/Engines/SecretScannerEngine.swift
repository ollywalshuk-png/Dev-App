import Foundation

public struct SecretScannerEngine: Sendable {
    public static let defaultMaximumFileBytes = 1_048_576

    public var maximumFileBytes: Int

    public init(maximumFileBytes: Int = Self.defaultMaximumFileBytes) {
        self.maximumFileBytes = maximumFileBytes
    }

    public func scan(repoRoot: URL) -> [SecretScanFinding] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: repoRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        guard let enumerator = fm.enumerator(
            at: repoRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: []
        ) else {
            return []
        }

        var findings: [SecretScanFinding] = []
        for case let url as URL in enumerator {
            if shouldSkip(url: url, repoRoot: repoRoot) {
                enumerator.skipDescendants()
                continue
            }

            guard shouldScanFile(url) else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            guard (values?.fileSize ?? 0) <= maximumFileBytes else { continue }

            findings.append(contentsOf: scanFile(url, repoRoot: repoRoot))
        }

        return findings.sorted {
            if $0.relativePath == $1.relativePath { return $0.lineNumber < $1.lineNumber }
            return $0.relativePath < $1.relativePath
        }
    }

    public func recommendations(from findings: [SecretScanFinding]) -> [RecommendationRecord] {
        findings.map { finding in
            RecommendationRecord(
                category: .safety,
                title: finding.recommendationTitle,
                summary: "\(finding.kind.rawValue) pattern detected. The matched value was redacted and is not stored in this recommendation.",
                targetPath: finding.path,
                sourceFilesAffected: true,
                severity: finding.severity,
                confidence: confidence(for: finding.kind),
                evidenceSummary: "\(finding.relativePath):\(finding.lineNumber) matched \(finding.reason). Preview: \(finding.redactedPreview)",
                impact: "Credentials committed to a repository can compromise developer accounts, signing assets, CI systems, or customer data.",
                suggestedAdjustment: "Remove the credential from tracked source, rotate it if it was real, and move repeatable build secrets to Keychain, environment injection, or an untracked local configuration file.",
                safetyWarning: "Do not paste the secret into PRs, chats, issue trackers, logs, or tracked files while investigating. LocalForge only reports the location and redacted pattern.",
                rollbackNote: "Use version control to review the manual removal. LocalForge does not delete, rewrite history, rotate credentials, or change files automatically."
            )
        }
    }

    private var supportedExtensions: Set<String> {
        [
            "swift", "m", "mm", "h", "hpp", "cpp", "c",
            "js", "ts", "tsx", "jsx", "py", "rb", "rs", "go", "kt", "java", "php",
            "sh", "bash", "zsh", "env", "json", "yml", "yaml", "toml", "ini",
            "properties", "xcconfig", "plist", "xml", "md"
        ]
    }

    private var explicitFileNames: Set<String> {
        [".env", ".env.local", ".env.development", ".env.production", ".npmrc", ".netrc"]
    }

    private var excludedNames: Set<String> {
        [
            ".git", ".build", ".swiftpm", "DerivedData", "node_modules", "Pods",
            "Carthage", ".cache", "dist", "build", ".venv", "venv", "vendor"
        ]
    }

    private func shouldSkip(url: URL, repoRoot: URL) -> Bool {
        guard url.path != repoRoot.path else { return false }
        return excludedNames.contains(url.lastPathComponent)
    }

    private func shouldScanFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if explicitFileNames.contains(name) || name.hasPrefix(".env.") { return true }
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func scanFile(_ url: URL, repoRoot: URL) -> [SecretScanFinding] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        guard let text, !text.isEmpty else { return [] }

        var findings: [SecretScanFinding] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (offset, rawLine) in lines.enumerated() {
            let line = String(rawLine)
            guard let match = classify(line) else { continue }
            findings.append(SecretScanFinding(
                path: url.path,
                relativePath: relativePath(for: url, root: repoRoot),
                lineNumber: offset + 1,
                kind: match.kind,
                redactedPreview: redactedPreview(for: line),
                reason: match.reason
            ))
        }
        return findings
    }

    private func classify(_ line: String) -> (kind: SecretFindingKind, reason: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPlaceholderOrRedacted(trimmed) else { return nil }

        if matches(#"-----BEGIN (?:RSA |EC |DSA |OPENSSH |)?PRIVATE KEY-----"#, in: trimmed, caseInsensitive: false) {
            return (.privateKeyMaterial, "private-key header")
        }

        if matches(#"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#, in: trimmed, caseInsensitive: false)
            || matches(#"gh[pousr]_[A-Za-z0-9_]{24,}"#, in: trimmed, caseInsensitive: false) {
            return (.providerToken, "known provider-token shape")
        }

        if matches(#"https?://[^/\s:@]+:[^/\s:@]+@"#, in: trimmed, caseInsensitive: true) {
            return (.embeddedCredential, "URL with embedded credentials")
        }

        if matches(assignmentPattern, in: trimmed, caseInsensitive: true) {
            return (.credentialAssignment, "credential-like assignment")
        }

        return nil
    }

    private var assignmentPattern: String {
        #"\b(?:password|passwd|pwd|api[_-]?(?:key|token)|access[_-]?token|refresh[_-]?token|secret|token|client[_-]?secret|notary[_-]?password|app[_-]?specific[_-]?password)\b\s*[:=]\s*["']?[^"'\s<>]{8,}"#
    }

    private func isPlaceholderOrRedacted(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.contains("<redacted>")
            || lowered.contains("<secret>")
            || lowered.contains("<password>")
            || lowered.contains("your_")
            || lowered.contains("placeholder")
            || lowered.contains("changeme")
            || lowered.contains("example")
    }

    private func redactedPreview(for line: String) -> String {
        var preview = line.trimmingCharacters(in: .whitespacesAndNewlines)
        preview = replace(#"(https?://)[^/\s:@]+:[^/\s:@]+@"#, in: preview, with: "$1<redacted>@")
        preview = replace(#"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#, in: preview, with: "<redacted-provider-token>", caseInsensitive: false)
        preview = replace(#"gh[pousr]_[A-Za-z0-9_]{24,}"#, in: preview, with: "<redacted-provider-token>", caseInsensitive: false)
        preview = replace(#"(["']?)[^"'\s<>]{8,}(["']?)$"#, in: preview, with: "$1<redacted>$2")
        preview = replace(#"-----BEGIN (?:RSA |EC |DSA |OPENSSH |)?PRIVATE KEY-----"#, in: preview, with: "-----BEGIN <redacted> PRIVATE KEY-----", caseInsensitive: false)

        if preview.count > 160 {
            return String(preview.prefix(157)) + "..."
        }
        return preview
    }

    private func matches(_ pattern: String, in text: String, caseInsensitive: Bool) -> Bool {
        range(of: pattern, in: text, caseInsensitive: caseInsensitive) != nil
    }

    private func replace(_ pattern: String, in text: String, with template: String, caseInsensitive: Bool = true) -> String {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private func range(of pattern: String, in text: String, caseInsensitive: Bool) -> Range<String.Index>? {
        let options: String.CompareOptions = caseInsensitive
            ? [.regularExpression, .caseInsensitive]
            : [.regularExpression]
        return text.range(of: pattern, options: options)
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func confidence(for kind: SecretFindingKind) -> Double {
        switch kind {
        case .credentialAssignment: 0.82
        case .providerToken: 0.96
        case .embeddedCredential: 0.9
        case .privateKeyMaterial: 0.98
        }
    }
}
