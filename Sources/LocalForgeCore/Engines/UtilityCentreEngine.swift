import Foundation

/// Phase 8.5 / Phase 9 — read-only utility runner with semantic result
/// classification, controlled timeouts, and async execution.
///
/// Every method is user-initiated. `run`-prefixed methods are async to keep
/// the UI responsive; pure target/classification helpers stay sync.
public struct UtilityCentreEngine: Sendable {
    public init() {}

    // MARK: - Status

    public enum Status: String, Hashable, Sendable {
        case success = "Success"
        case info = "Info"
        case warning = "Warning"
        case failure = "Failure"
        case targetError = "Target Error"
        case timeout = "Timeout"
        case blocked = "Blocked"

        public var symbolName: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .failure: "xmark.circle.fill"
            case .targetError: "questionmark.app"
            case .timeout: "clock.badge.exclamationmark"
            case .blocked: "hand.raised.fill"
            }
        }
    }

    // MARK: - Timeouts (seconds)

    public struct Timeouts: Sendable {
        public static let metadata: TimeInterval = 10
        public static let signing: TimeInterval = 15
        public static let repo: TimeInterval = 30
        public static let largeScan: TimeInterval = 45
    }

    // MARK: - Output limits

    /// Maximum bytes of combined stdout+stderr we keep per command. Anything
    /// over is truncated with a clear marker.
    public static let maxOutputBytes = 256 * 1024

    // MARK: - Target resolution

    /// Discover candidate `.app` bundles under a repository root. Used by
    /// security and bundle tools so they never run against a repo root.
    /// Returns paths in priority order: `dist/*.app` first, then siblings,
    /// then `.build/**/*.app`. Within each tier, newest-first by mtime.
    public func findAppBundles(under repoRoot: String, maxCandidates: Int = 20) -> [String] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: repoRoot)

        var distApps: [(URL, Date)] = []
        var directApps: [(URL, Date)] = []
        var nestedApps: [(URL, Date)] = []

        // Tier 1: dist/*.app at any depth (but skip .build/.git).
        // Tier 2: direct children ending in .app.
        // Tier 3: .build/**/*.app — only if user opts in.
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            // Don't descend into .git internals.
            if url.pathComponents.contains(".git") {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension == "app" else { continue }
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let inDist = url.deletingLastPathComponent().lastPathComponent == "dist"
            let inBuild = url.pathComponents.contains(".build")

            if inDist {
                distApps.append((url, mtime))
            } else if inBuild {
                nestedApps.append((url, mtime))
            } else if url.deletingLastPathComponent().path == root.path {
                directApps.append((url, mtime))
            } else {
                nestedApps.append((url, mtime))
            }
            // Don't descend into the .app bundle itself.
            enumerator.skipDescendants()
            if distApps.count + directApps.count + nestedApps.count >= maxCandidates * 3 {
                break
            }
        }

        let sorted: [(URL, Date)] = distApps.sorted { $0.1 > $1.1 }
            + directApps.sorted { $0.1 > $1.1 }
            + nestedApps.sorted { $0.1 > $1.1 }
        return sorted.prefix(maxCandidates).map { $0.0.path }
    }

    /// True if `path` points to something that looks like an app bundle:
    /// extension `.app`, is a directory, and `Contents/Info.plist` exists.
    public func isAppBundle(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension == "app" else { return false }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    }

    // MARK: - Security Toolkit (async)

    public func runQuarantineInspector(path: String) async -> UtilityResult {
        guard validateExists(path: path) else { return targetMissing(title: "Quarantine Inspector", path: path) }
        let r = await run(args: ["/usr/bin/xattr", "-p", "com.apple.quarantine", path],
                          timeout: Timeouts.metadata)
        return classifyQuarantineInspector(r, path: path)
    }

    public func runRemoveQuarantine(path: String) async -> UtilityResult {
        guard validateExists(path: path) else { return targetMissing(title: "Remove Quarantine", path: path) }
        // Check first — if no quarantine, don't mutate.
        let check = await run(args: ["/usr/bin/xattr", "-l", path], timeout: Timeouts.metadata)
        if !check.combined.contains("com.apple.quarantine") {
            return UtilityResult(
                title: "Remove Quarantine — \(URL(fileURLWithPath: path).lastPathComponent)",
                status: .info,
                output: "No quarantine attribute present; nothing removed.",
                command: "xattr -l <path>",
                target: path,
                interpretation: "Clean.",
                nextAction: "No action required."
            )
        }
        let r = await run(args: ["/usr/bin/xattr", "-dr", "com.apple.quarantine", path],
                          timeout: Timeouts.metadata)
        return UtilityResult(
            title: "Remove Quarantine — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: r.exitCode == 0 ? .success : .failure,
            output: r.combined.isEmpty ? "Quarantine removed." : r.combined,
            command: "xattr -dr com.apple.quarantine <path>",
            target: path,
            interpretation: r.exitCode == 0 ? "Quarantine attribute removed." : "Could not remove quarantine.",
            nextAction: r.exitCode == 0 ? "None." : "Re-run with appropriate permissions."
        )
    }

    public func runGatekeeperCheck(path: String) async -> UtilityResult {
        guard requireAppBundle(path: path, title: "Gatekeeper Check") == nil else {
            return requireAppBundle(path: path, title: "Gatekeeper Check")!
        }
        let r = await run(args: ["/usr/sbin/spctl", "--assess", "--verbose=4", path],
                          timeout: Timeouts.signing)
        return classifyGatekeeperCheck(r, path: path)
    }

    public func runSignatureInspector(path: String) async -> UtilityResult {
        if let err = requireAppBundle(path: path, title: "Signature Inspector") { return err }
        let r = await run(args: ["/usr/bin/codesign", "-dv", "--verbose=4", path],
                          timeout: Timeouts.signing)
        return UtilityResult(
            title: "Signature Inspector — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: r.exitCode == 0 ? .info : .failure,
            output: r.combined,
            command: "codesign -dv --verbose=4 <path>",
            target: path,
            interpretation: r.combined.contains("adhoc") ? "Adhoc-signed (local development build)." : "Signed; see details.",
            nextAction: ""
        )
    }

    public func runSignatureVerification(path: String) async -> UtilityResult {
        if let err = requireAppBundle(path: path, title: "Signature Verification") { return err }
        let r = await run(args: ["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", path],
                          timeout: Timeouts.signing)
        return UtilityResult(
            title: "Signature Verification — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: r.exitCode == 0 ? .success : .failure,
            output: r.combined.isEmpty ? "Signature valid." : r.combined,
            command: "codesign --verify --deep --strict <path>",
            target: path,
            interpretation: r.exitCode == 0 ? "Signature integrity OK." : "Signature integrity failed.",
            nextAction: r.exitCode == 0 ? "" : "Re-sign the bundle (build_and_run.sh now does this)."
        )
    }

    public func runEntitlements(path: String) async -> UtilityResult {
        if let err = requireAppBundle(path: path, title: "Entitlements") { return err }
        let r = await run(args: ["/usr/bin/codesign", "-d", "--entitlements", "-", path],
                          timeout: Timeouts.signing)
        return UtilityResult(
            title: "Entitlements — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: r.exitCode == 0 ? .info : .failure,
            output: r.combined.isEmpty ? "No entitlements." : r.combined,
            command: "codesign -d --entitlements - <path>",
            target: path,
            interpretation: "",
            nextAction: ""
        )
    }

    public func runNotarisationCheck(path: String) async -> UtilityResult {
        if let err = requireAppBundle(path: path, title: "Notarisation Check") { return err }
        let r = await run(args: ["/usr/sbin/spctl", "--assess", "--type", "execute", "--verbose", path],
                          timeout: Timeouts.signing)
        return classifyNotarisationCheck(r, path: path)
    }

    // MARK: - Build Utilities

    public func runDerivedDataSize() async -> UtilityResult {
        let ddPath = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        guard FileManager.default.fileExists(atPath: ddPath) else {
            return UtilityResult(
                title: "DerivedData Size",
                status: .info,
                output: "DerivedData folder not found; nothing to measure.",
                command: "du -sh \(ddPath)",
                target: ddPath,
                interpretation: "Clean.",
                nextAction: "No action required."
            )
        }
        let r = await run(args: ["/usr/bin/du", "-sh", ddPath], timeout: Timeouts.repo)
        return UtilityResult(
            title: "DerivedData Size",
            status: r.exitCode == 0 ? .info : .warning,
            output: r.combined,
            command: "du -sh \(ddPath)",
            target: ddPath,
            interpretation: "",
            nextAction: ""
        )
    }

    public func runCleanDerivedData() async -> UtilityResult {
        let ddPath = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        guard FileManager.default.fileExists(atPath: ddPath) else {
            return UtilityResult(
                title: "Clean DerivedData",
                status: .info,
                output: "DerivedData folder not found; nothing to clean.",
                command: "rm -rf \(ddPath)",
                target: ddPath,
                interpretation: "Clean.",
                nextAction: "No action required."
            )
        }
        let r = await run(args: ["/bin/rm", "-rf", ddPath], timeout: Timeouts.repo)
        return UtilityResult(
            title: "Clean DerivedData",
            status: r.exitCode == 0 ? .success : .failure,
            output: r.combined.isEmpty ? "DerivedData removed." : r.combined,
            command: "rm -rf \(ddPath)",
            target: ddPath,
            interpretation: r.exitCode == 0 ? "DerivedData cleared." : "",
            nextAction: ""
        )
    }

    public func runBundleInspector(path: String) async -> UtilityResult {
        if let err = requireAppBundle(path: path, title: "Bundle Inspector") { return err }
        let plistPath = URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist").path
        let r = await run(args: ["/usr/bin/plutil", "-p", plistPath], timeout: Timeouts.metadata)
        return UtilityResult(
            title: "Bundle Inspector — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: r.exitCode == 0 ? .info : .failure,
            output: r.combined,
            command: "plutil -p <bundle>/Contents/Info.plist",
            target: path,
            interpretation: "",
            nextAction: ""
        )
    }

    // MARK: - Repository Utilities

    public func runGitHealth(repoRoot: String) async -> UtilityResult {
        guard validateExists(path: repoRoot) else { return targetMissing(title: "Git Health", path: repoRoot) }
        let r = await run(args: ["/usr/bin/git", "-C", repoRoot, "status", "--short", "--branch"],
                          timeout: Timeouts.metadata)
        return UtilityResult(
            title: "Git Health — \(URL(fileURLWithPath: repoRoot).lastPathComponent)",
            status: r.exitCode == 0 ? .info : .warning,
            output: r.combined.isEmpty ? "(no output)" : r.combined,
            command: "git -C <repo> status --short --branch",
            target: repoRoot,
            interpretation: r.combined.contains("nothing to commit") ? "Working tree clean." : "",
            nextAction: ""
        )
    }

    /// Group of files surfaced by largeFiles. Used by the view to bucket noise.
    public enum LargeFileGroup: String, CaseIterable, Sendable {
        case appBundle = "App Bundles"
        case buildArtefact = "Build Artefacts"
        case debugSymbols = "Debug Symbols"
        case moduleCache = "Module Cache"
        case gitObjects = "Git Objects"
        case sourceAssets = "Source Assets"
        case archives = "Archives"
        case other = "Other"
    }

    public struct LargeFileResult: Sendable {
        public var path: String
        public var sizeBytes: Int64
        public var group: LargeFileGroup
    }

    public func runLargeFiles(
        repoRoot: String,
        thresholdKB: Int = 1024,
        includeBuildArtefacts: Bool = false
    ) async -> (UtilityResult, [LargeFileResult]) {
        guard validateExists(path: repoRoot) else {
            return (targetMissing(title: "Large File Finder", path: repoRoot), [])
        }
        let r = await run(
            args: ["/usr/bin/find", repoRoot, "-size", "+\(thresholdKB)k", "-type", "f"],
            timeout: Timeouts.largeScan
        )
        let lines = r.combined.split(separator: "\n").map(String.init)
        var entries: [LargeFileResult] = []
        for line in lines.prefix(2000) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: line)
            let size = (attrs?[.size] as? Int64) ?? 0
            let group = classifyLargeFile(path: line)
            entries.append(LargeFileResult(path: line, sizeBytes: size, group: group))
        }
        if !includeBuildArtefacts {
            entries = entries.filter {
                $0.group != .buildArtefact && $0.group != .moduleCache && $0.group != .gitObjects
            }
        }
        entries.sort { $0.sizeBytes > $1.sizeBytes }
        let topN = Array(entries.prefix(50))

        let summary = topN.isEmpty
            ? "No large files matching filter."
            : "\(topN.count) large file(s) found. \(entries.count - topN.count > 0 ? "Showing top 50." : "")"
        let result = UtilityResult(
            title: "Large File Finder — \(URL(fileURLWithPath: repoRoot).lastPathComponent)",
            status: r.timedOut ? .timeout : .info,
            output: summary,
            command: "find <repo> -size +\(thresholdKB)k -type f",
            target: repoRoot,
            interpretation: "",
            nextAction: ""
        )
        return (result, topN)
    }

    public func runEmptyFolders(
        repoRoot: String,
        includeBuildAndCache: Bool = false
    ) async -> UtilityResult {
        guard validateExists(path: repoRoot) else { return targetMissing(title: "Empty Folder Finder", path: repoRoot) }
        let r = await run(
            args: ["/usr/bin/find", repoRoot, "-type", "d", "-empty"],
            timeout: Timeouts.largeScan
        )
        let ignore = [".git", ".build", ".swiftpm", "ModuleCache", "DerivedData", "checkouts", "repositories", "swiftpm-cache"]
        var lines = r.combined.split(separator: "\n").map(String.init)
        if !includeBuildAndCache {
            lines = lines.filter { line in
                !ignore.contains { line.contains("/\($0)/") || line.hasSuffix("/\($0)") }
            }
        }
        let output = lines.isEmpty ? "No empty folders." : lines.prefix(100).joined(separator: "\n")
        let suffix = lines.count > 100 ? "\n… and \(lines.count - 100) more." : ""

        return UtilityResult(
            title: "Empty Folder Finder — \(URL(fileURLWithPath: repoRoot).lastPathComponent)",
            status: r.timedOut ? .timeout : .info,
            output: output + suffix,
            command: "find <repo> -type d -empty",
            target: repoRoot,
            interpretation: includeBuildAndCache ? "" : "Build and cache folders excluded by default.",
            nextAction: ""
        )
    }

    // MARK: - Environment capture

    public func captureEnvironment() async -> EnvironmentSnapshot {
        async let macOS = shell(["/usr/bin/sw_vers", "-productVersion"])
        async let xcode = shell(["/usr/bin/xcode-select", "-p"])
        async let swift = shell(["/usr/bin/swift", "--version"])
        async let sdk = shell(["/usr/bin/xcrun", "--show-sdk-path"])

        let macOSVal = await macOS
        let xcodeVal = await xcode
        let swiftVal = await swift
        let sdkVal = await sdk

        return EnvironmentSnapshot(
            macOSVersion: macOSVal,
            xcodeVersion: xcodeVal,
            swiftVersion: swiftVal.components(separatedBy: "\n").first ?? swiftVal,
            sdkVersion: sdkVal,
            auValVersion: ""
        )
    }

    private func shell(_ args: [String]) async -> String {
        let r = await run(args: args, timeout: UtilityCentreEngine.Timeouts.metadata)
        return r.combined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Classification helpers (pure — testable)

    public func classifyQuarantineInspector(_ raw: ProcessResult, path: String) -> UtilityResult {
        // xattr returns non-zero "No such xattr: com.apple.quarantine" when there is no quarantine attr — that's CLEAN, not failure.
        let cleanMarker = "No such xattr"
        if raw.exitCode != 0 && raw.combined.contains(cleanMarker) {
            return UtilityResult(
                title: "Quarantine Inspector — \(URL(fileURLWithPath: path).lastPathComponent)",
                status: .success,
                output: "No quarantine attribute present.",
                command: "xattr -p com.apple.quarantine <path>",
                target: path,
                interpretation: "Clean — not quarantined.",
                nextAction: "No action required."
            )
        }
        if raw.timedOut {
            return UtilityResult(
                title: "Quarantine Inspector — \(URL(fileURLWithPath: path).lastPathComponent)",
                status: .timeout, output: raw.combined,
                command: "xattr -p com.apple.quarantine <path>", target: path,
                interpretation: "Command exceeded timeout.", nextAction: ""
            )
        }
        return UtilityResult(
            title: "Quarantine Inspector — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: raw.exitCode == 0 ? .warning : .failure,
            output: raw.combined,
            command: "xattr -p com.apple.quarantine <path>",
            target: path,
            interpretation: raw.exitCode == 0 ? "Quarantine attribute is set." : "",
            nextAction: raw.exitCode == 0 ? "Run Remove Quarantine if intentional." : ""
        )
    }

    public func classifyGatekeeperCheck(_ raw: ProcessResult, path: String) -> UtilityResult {
        if raw.exitCode == 0 {
            return UtilityResult(
                title: "Gatekeeper Check — \(URL(fileURLWithPath: path).lastPathComponent)",
                status: .success, output: raw.combined,
                command: "spctl --assess --verbose=4 <path>", target: path,
                interpretation: "Gatekeeper accepts this bundle.", nextAction: ""
            )
        }
        let adhocReject = raw.combined.contains("no resources but signature indicates")
        let unsigned = raw.combined.contains("not signed at all") || raw.combined.contains("rejected")
        let info = (adhocReject || unsigned)
            ? "Adhoc / locally signed — Gatekeeper rejects without Developer ID + notarisation. Expected for dev builds."
            : "Gatekeeper rejected the bundle."
        return UtilityResult(
            title: "Gatekeeper Check — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: (adhocReject || unsigned) ? .info : .failure,
            output: raw.combined,
            command: "spctl --assess --verbose=4 <path>", target: path,
            interpretation: info,
            nextAction: (adhocReject || unsigned) ? "Distribution-phase only: sign with Developer ID and notarise." : ""
        )
    }

    public func classifyNotarisationCheck(_ raw: ProcessResult, path: String) -> UtilityResult {
        if raw.exitCode == 0 {
            return UtilityResult(
                title: "Notarisation Check — \(URL(fileURLWithPath: path).lastPathComponent)",
                status: .success, output: raw.combined,
                command: "spctl --assess --type execute --verbose <path>", target: path,
                interpretation: "Notarised and accepted.", nextAction: ""
            )
        }
        return UtilityResult(
            title: "Notarisation Check — \(URL(fileURLWithPath: path).lastPathComponent)",
            status: .info, output: raw.combined,
            command: "spctl --assess --type execute --verbose <path>", target: path,
            interpretation: "Not notarised / not distribution signed. Expected for local development.",
            nextAction: "Distribution-phase only: notarise with notarytool."
        )
    }

    public func classifyLargeFile(path: String) -> LargeFileGroup {
        let p = path.lowercased()
        if p.contains("/.build/") || p.hasSuffix(".o") || p.hasSuffix(".swiftmodule") || p.contains("/build/") {
            return .buildArtefact
        }
        if p.contains("/modulecache") || p.hasSuffix(".pcm") { return .moduleCache }
        if p.contains("/.git/") { return .gitObjects }
        if p.hasSuffix(".dsym") || p.contains(".dsym/") { return .debugSymbols }
        if p.hasSuffix(".app") || p.contains(".app/") { return .appBundle }
        if p.contains("/archives/") || p.hasSuffix(".xcarchive") || p.contains(".xcarchive/") { return .archives }
        if p.hasSuffix(".png") || p.hasSuffix(".jpg") || p.hasSuffix(".pdf") || p.hasSuffix(".mp3") || p.hasSuffix(".mp4") { return .sourceAssets }
        return .other
    }

    // MARK: - Target validation

    private func requireAppBundle(path: String, title: String) -> UtilityResult? {
        guard validateExists(path: path) else { return targetMissing(title: title, path: path) }
        guard isAppBundle(path) else {
            return UtilityResult(
                title: title,
                status: .targetError,
                output: "Selected target is not an app bundle.",
                command: "",
                target: path,
                interpretation: "This tool requires a .app bundle (with Contents/Info.plist).",
                nextAction: "Choose a .app bundle, or use Find App Bundles to locate one under the repo root."
            )
        }
        return nil
    }

    private func validateExists(path: String) -> Bool {
        !path.isEmpty && FileManager.default.fileExists(atPath: path)
    }

    private func targetMissing(title: String, path: String) -> UtilityResult {
        UtilityResult(
            title: title,
            status: .targetError,
            output: path.isEmpty ? "No target specified." : "Path does not exist: \(path)",
            command: "",
            target: path,
            interpretation: "Tool cannot run without a valid target.",
            nextAction: "Set a Target Path."
        )
    }

    // MARK: - Process runner (async, with timeout + size cap)

    public struct ProcessResult: Sendable {
        public var exitCode: Int32
        public var combined: String
        public var timedOut: Bool
        public var truncated: Bool
    }

    public func run(args: [String], timeout: TimeInterval) async -> ProcessResult {
        await withCheckedContinuation { (cont: CheckedContinuation<ProcessResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: args[0])
                process.arguments = Array(args.dropFirst())
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                // Drain both pipes concurrently while the process runs. Reading
                // only after waitUntilExit() deadlocks once a command emits more
                // than the OS pipe buffer (~64KB): the child blocks on write, the
                // parent blocks on wait. A serial queue guards the accumulators.
                let cap = UtilityCentreEngine.maxOutputBytes
                let accumQueue = DispatchQueue(label: "utility.run.accum")
                let sink = OutputSink()
                let group = DispatchGroup()

                group.enter()
                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        group.leave()
                        return
                    }
                    accumQueue.async { sink.appendOut(chunk, cap: cap) }
                }

                group.enter()
                errPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        group.leave()
                        return
                    }
                    accumQueue.async { sink.appendErr(chunk, cap: cap) }
                }

                do {
                    try process.run()
                } catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    cont.resume(returning: ProcessResult(
                        exitCode: -1,
                        combined: "Error: \(error.localizedDescription)",
                        timedOut: false,
                        truncated: false
                    ))
                    return
                }

                // Timeout watchdog.
                let timeoutFired = DispatchSemaphore(value: 0)
                var didTimeout = false
                let timeoutWork = DispatchWorkItem {
                    if process.isRunning {
                        didTimeout = true
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                _ = timeoutFired

                process.waitUntilExit()
                timeoutWork.cancel()
                // Wait for both pipe handlers to see EOF so no bytes are lost.
                _ = group.wait(timeout: .now() + 5)

                let (finalOut, finalErr, finalTruncated): (Data, Data, Bool) = accumQueue.sync {
                    (sink.out, sink.err, sink.truncated)
                }

                let out = String(data: finalOut, encoding: .utf8) ?? ""
                let err = String(data: finalErr, encoding: .utf8) ?? ""
                var combined = [out, err].filter { !$0.isEmpty }.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if finalTruncated {
                    combined += "\n\n— Output truncated at \(cap / 1024) KB. Full output available via shell. —"
                }

                cont.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    combined: combined.isEmpty ? "(no output)" : combined,
                    timedOut: didTimeout,
                    truncated: finalTruncated
                ))
            }
        }
    }
}

/// Accumulator for process output. All access is serialised by the caller's
/// `accumQueue`, so the class itself does no locking — it exists only to give
/// the readability handlers a `let` reference to capture (avoiding mutable-var
/// captures in concurrently-executing closures).
private final class OutputSink: @unchecked Sendable {
    var out = Data()
    var err = Data()
    var truncated = false

    func appendOut(_ chunk: Data, cap: Int) {
        if out.count < cap {
            out.append(chunk)
            if out.count > cap { out = out.prefix(cap); truncated = true }
        } else {
            truncated = true
        }
    }

    func appendErr(_ chunk: Data, cap: Int) {
        if err.count < cap {
            err.append(chunk)
            if err.count > cap { err = err.prefix(cap); truncated = true }
        } else {
            truncated = true
        }
    }
}
