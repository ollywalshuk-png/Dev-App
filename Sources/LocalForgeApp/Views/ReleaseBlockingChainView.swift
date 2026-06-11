import LocalForgeCore
import SwiftUI

/// Phase 8.5 — Release Blocking Chain. Visual, clickable dependency tree showing
/// exactly what is blocking release and why.
struct ReleaseBlockingChainView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        Group {
            if let project = store.selectedProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(project: project)
                        if let root = store.releaseBlockingChain(for: project.id) {
                            if root.children.isEmpty {
                                ContentUnavailableView(
                                    "No blockers",
                                    systemImage: "checkmark.circle.fill",
                                    description: Text("Nothing is blocking release for this project.")
                                )
                            } else {
                                blockNode(root, depth: 0)
                            }
                        } else {
                            ContentUnavailableView(
                                "No release readiness data",
                                systemImage: "flag.checkered",
                                description: Text("Set up the project mission and verification areas first.")
                            )
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("No project selected", systemImage: "flag.checkered",
                    description: Text("Select a project to see its release blocking chain."))
            }
        }
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Release Blocking Chain")
                .font(.system(size: 28, weight: .bold))
            Text(project.name)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func blockNode(_ node: ReleaseBlockNode, depth: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    if depth > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 14)
                            .padding(.leading, CGFloat(depth) * 22)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 14, height: 1)
                    }
                    BlockNodeCard(node: node, onTap: { navigate(to: node) })
                        .padding(.leading, depth == 0 ? 0 : 4)
                }
                ForEach(node.children) { child in
                    blockNode(child, depth: depth + 1)
                }
            }
        )
    }

    private func navigate(to node: ReleaseBlockNode) {
        switch node.kind {
        case .release:
            store.selectedModule = .releaseReadiness
        case .verification:
            store.selectedModule = .verification
        case .risk:
            store.selectedModule = .registers
        case .dependency:
            store.selectedModule = .verification
        }
    }
}

private struct BlockNodeCard: View {
    var node: ReleaseBlockNode
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: nodeIcon)
                    .foregroundStyle(nodeColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.label)
                        .font(.system(size: 13, weight: node.kind == .release ? .bold : .medium))
                        .lineLimit(1)
                    Text(node.state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if node.isBlocking {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(node.isBlocking ? Color.red.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var nodeIcon: String {
        switch node.kind {
        case .release: "flag.checkered"
        case .verification: "checkmark.seal"
        case .risk: "exclamationmark.shield"
        case .dependency: "arrow.down.circle"
        }
    }

    private var nodeColor: Color {
        if node.isBlocking {
            return node.kind == .release ? .primary : .red
        }
        return .secondary
    }
}
