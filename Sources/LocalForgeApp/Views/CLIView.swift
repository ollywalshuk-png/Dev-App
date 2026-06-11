import SwiftUI

struct CLIView: View {
    @State private var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CLI Companion")
                    .font(.title2.weight(.semibold))
                Label("Thin read-only wrapper over LocalForgeCore. It scans explicit paths only and never modifies repositories.", systemImage: "eye")
                    .foregroundStyle(.secondary)
            }

            ExplanationCard(
                title: "CLI Companion",
                what: "The CLI is a read-only companion for generating project summaries and checking command safety from Terminal.",
                why: "It gives advanced users a scriptable way to inspect explicit project paths without opening the full app.",
                next: "Use scan for a local summary, report for a redacted handoff, and assess-command before running risky terminal commands.",
                safety: "The CLI does not add mutating commands in V1. Destructive commands are classified by CommandSafetyEngine rather than executed.",
                example: "Example: localforge report /path/to/project",
                symbol: "terminal",
                tint: .green
            )

            CommandPreview(
                title: "Scan a project",
                command: "localforge scan /path/to/project",
                copiedCommand: $copiedCommand
            )
            CommandPreview(
                title: "Print a redacted report",
                command: "localforge report /path/to/project",
                copiedCommand: $copiedCommand
            )
            CommandPreview(
                title: "Assess command safety",
                command: "localforge assess-command \"git reset --hard\"",
                copiedCommand: $copiedCommand
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Safety")
                    .font(.headline)
                Text("Destructive shell and Git commands are blocked by CommandSafetyEngine. The CLI does not add mutating commands in V1.")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct CommandPreview: View {
    var title: String
    var command: String
    @Binding var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if copiedCommand == command {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            HStack {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copiedCommand = command
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy command")
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
