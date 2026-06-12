import AppKit
import LocalForgeCore
import SwiftUI

struct TestRegistryView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var editingRecord: TestRecord?

    var body: some View {
        guard let project = store.selectedProject else {
            return AnyView(ContentUnavailableView(
                "No project selected",
                systemImage: "checklist.checked",
                description: Text("Open or select a project to record manual, automated, regression, integration, and host test evidence.")
            ))
        }

        let records = store.testRecords(for: project.id)
        return AnyView(VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2.weight(.semibold))
                    Label("Read-only registry: records observations; does not run tests or modify repositories.", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editingRecord = TestRecord(name: "", author: NSFullUserName())
                } label: {
                    Label("Add Test Record", systemImage: "plus")
                }
            }

            ExplanationCard(
                title: "Test Registry",
                what: "The Test Registry records manual, automated, regression, integration, and host-test results.",
                why: "Tests support verification, but a test record does not automatically prove an area unless it is linked or promoted as evidence.",
                next: "Add a test result, choose an outcome, and link it to the verification area it supports.",
                safety: "This registry stores observations. It does not run commands or modify repositories.",
                example: "Use Dev Tools for preset Swift Test runs; use this screen for manual QA, host tests, or notes from external tools.",
                symbol: "testtube.2",
                tint: .blue
            )

            if records.isEmpty {
                ContentUnavailableView(
                    "No test records",
                    systemImage: "testtube.2",
                    description: Text("Add the first observed result, choose an outcome, and link it to a verification area when useful.")
                )
            } else {
                testSummary(records)
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(TestKind.allCases, id: \.self) { kind in
                        let grouped = records.filter { $0.kind == kind }
                        if !grouped.isEmpty {
                            TestGroupView(
                                kind: kind,
                                records: grouped,
                                onEdit: { editingRecord = $0 },
                                onCopy: copySummary
                            )
                        }
                    }
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            TestRecordEditorView(
                record: record,
                verificationAreas: store.selectedSnapshot?.verification.map(\.area) ?? [],
                onCancel: { editingRecord = nil },
                onSave: { saved in
                    store.addTestRecord(saved, for: project.id)
                    editingRecord = nil
                }
            )
        })
    }

    private func testSummary(_ records: [TestRecord]) -> some View {
        let now = Date()
        let evidenceLinked = records.filter { !$0.linkedEvidenceIDs.isEmpty }.count
        let manual = records.filter { $0.kind == .manual }.count
        let stale = records.filter { testObservationFreshness(for: $0.testedAt, referenceDate: now) == .stale }.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            StatCell(label: "Passed", value: "\(records.filter { $0.outcome == .passed }.count)", color: .green)
            StatCell(label: "Failed", value: "\(records.filter { $0.outcome == .failed }.count)", color: .red)
            StatCell(label: "Blocked", value: "\(records.filter { $0.outcome == .blocked }.count)", color: .orange)
            StatCell(label: "Unknown", value: "\(records.filter { $0.outcome == .unknown }.count)", color: .gray)
            StatCell(label: "Evidence Linked", value: "\(evidenceLinked)", color: evidenceLinked == records.count ? .green : .indigo)
            StatCell(label: "Manual", value: "\(manual)", color: manual > 0 ? .purple : .gray)
            StatCell(label: "Stale", value: "\(stale)", color: stale > 0 ? .orange : .gray)
        }
    }

    private func copySummary(_ record: TestRecord) {
        let summary = """
        Test: \(record.name)
        Kind: \(record.kind.rawValue)
        Outcome: \(record.outcome.rawValue)
        Verification: \(record.linkedVerificationArea.isEmpty ? "Unlinked" : record.linkedVerificationArea)
        Evidence IDs: \(record.linkedEvidenceIDs.count)
        Tested: \(record.testedAt.formatted(date: .abbreviated, time: .shortened))
        Notes: \(record.notes)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}

private let staleTestObservationInterval: TimeInterval = 60 * 60 * 24 * 30
private let recentTestObservationInterval: TimeInterval = 60 * 60 * 24 * 7

private enum TestObservationFreshness: Equatable {
    case fresh
    case recent
    case stale
    case future

    var label: String {
        switch self {
        case .fresh: "Fresh <7d"
        case .recent: "Recent <30d"
        case .stale: "Stale 30d+"
        case .future: "Future date"
        }
    }

    var symbolName: String {
        switch self {
        case .fresh: "checkmark.circle.fill"
        case .recent: "clock"
        case .stale: "clock.badge.exclamationmark"
        case .future: "calendar"
        }
    }

    var color: Color {
        switch self {
        case .fresh: .green
        case .recent: .blue
        case .stale, .future: .orange
        }
    }
}

private func testObservationFreshness(for testedAt: Date, referenceDate: Date = Date()) -> TestObservationFreshness {
    let age = referenceDate.timeIntervalSince(testedAt)
    if age < 0 {
        return .future
    }
    if age < recentTestObservationInterval {
        return .fresh
    }
    if age < staleTestObservationInterval {
        return .recent
    }
    return .stale
}

private struct RegistryHelpPanel: View {
    var title: String
    var message: String
    var symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TestGroupView: View {
    var kind: TestKind
    var records: [TestRecord]
    var onEdit: (TestRecord) -> Void
    var onCopy: (TestRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.rawValue)
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                ForEach(records) { record in
                    TestRecordCard(record: record, onEdit: onEdit, onCopy: onCopy)
                }
            }
        }
    }
}

private struct TestRecordCard: View {
    var record: TestRecord
    var onEdit: (TestRecord) -> Void
    var onCopy: (TestRecord) -> Void

    var body: some View {
        let freshness = testObservationFreshness(for: record.testedAt)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TestTrustChip(text: record.outcome.rawValue, symbol: record.outcome.symbolName, color: outcomeColor)
                        TestTrustChip(text: freshness.label, symbol: freshness.symbolName, color: freshness.color)
                    }
                    HStack(spacing: 6) {
                        TestTrustChip(text: evidenceLabel, symbol: evidenceSymbolName, color: evidenceColor)
                        TestTrustChip(
                            text: record.kind == .manual ? "Manual" : record.kind.rawValue,
                            symbol: record.kind == .manual ? "person" : "checklist.checked",
                            color: record.kind == .manual ? .purple : .blue
                        )
                    }
                }
                Spacer()
                Button { onCopy(record) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy test summary")
                Button { onEdit(record) } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit test record")
            }

            Text(record.name.isEmpty ? "Untitled test" : record.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)

            if !record.linkedVerificationArea.isEmpty {
                Label(record.linkedVerificationArea, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Unlinked verification area", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Label(record.author.isEmpty ? "Observer unknown" : record.author, systemImage: "person")
                Spacer()
                Text(record.testedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(record.outcome.releaseReadinessImpact)
                .font(.caption.weight(.medium))
                .foregroundStyle(outcomeColor)

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(outcomeColor.opacity(0.25))
        )
    }

    private var evidenceLabel: String {
        if record.linkedEvidenceIDs.isEmpty {
            return "No evidence"
        }
        return "\(record.linkedEvidenceIDs.count) evidence"
    }

    private var evidenceSymbolName: String {
        record.linkedEvidenceIDs.isEmpty ? "exclamationmark.triangle.fill" : "paperclip"
    }

    private var evidenceColor: Color {
        record.linkedEvidenceIDs.isEmpty ? .orange : .indigo
    }

    private var outcomeColor: Color {
        switch record.outcome {
        case .passed: .green
        case .failed: .red
        case .blocked: .orange
        case .skipped: .secondary
        case .unknown: .gray
        }
    }
}

private struct TestTrustChip: View {
    var text: String
    var symbol: String
    var color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct TestRecordEditorView: View {
    @State private var draft: TestRecord
    var verificationAreas: [String]
    var onCancel: () -> Void
    var onSave: (TestRecord) -> Void

    init(record: TestRecord, verificationAreas: [String], onCancel: @escaping () -> Void, onSave: @escaping (TestRecord) -> Void) {
        _draft = State(initialValue: record)
        self.verificationAreas = verificationAreas
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Result") {
                TextField("Test name", text: $draft.name)
                Picker("Kind", selection: $draft.kind) {
                    ForEach(TestKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Outcome", selection: $draft.outcome) {
                    ForEach(TestOutcome.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Verification area", selection: $draft.linkedVerificationArea) {
                    Text("Unlinked").tag("")
                    ForEach(verificationAreas, id: \.self) { Text($0).tag($0) }
                }
                DatePicker("Tested", selection: $draft.testedAt)
            }
            Section("Notes") {
                TextField("Verified by", text: $draft.author)
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 100)
                Text("This registry stores observed test results only. It does not execute commands or change source files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 520)
    }
}
