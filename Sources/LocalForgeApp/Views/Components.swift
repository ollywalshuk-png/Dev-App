import LocalForgeCore
import SwiftUI

extension ProjectKind {
    /// Accent colour for this project type. Lives in the App layer so
    /// LocalForgeCore stays free of SwiftUI.
    var tint: Color {
        switch self {
        case .swiftUIApp: .blue
        case .appKitApp: .indigo
        case .uiKitApp: .indigo
        case .audioUnitInstrument: .pink
        case .audioUnitEffect: .pink
        case .audioUnitPlugin: .pink
        case .framework: .purple
        case .commandLineTool: .teal
        case .xcodeApp: .blue
        case .swiftPackage: .orange
        case .nodeWeb: .green
        case .pythonProject: .teal
        case .rustProject: .brown
        case .goProject: .cyan
        case .unidentified: .gray
        }
    }
}

struct LiquidGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 8
    var tint: Color = .accentColor
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.26 : 0.16),
                                tint.opacity(isActive ? 0.18 : 0.08),
                                Color.black.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.34 : 0.20),
                                tint.opacity(isActive ? 0.46 : 0.20),
                                Color.black.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isActive ? 1.2 : 1
                    )
            )
            .shadow(color: tint.opacity(isActive ? 0.18 : 0.07), radius: isActive ? 12 : 7, x: 0, y: 3)
    }
}

extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = 8,
        tint: Color = .accentColor,
        isActive: Bool = false
    ) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius, tint: tint, isActive: isActive))
    }
}

/// Traffic-light health derived from a snapshot's findings + access state.
enum ProjectHealth {
    case healthy, warning, critical, attention, unknown

    static func resolve(project: ProjectContext, snapshot: RepoSnapshot?) -> ProjectHealth {
        if project.bookmarkStatus.requiresAttention { return .attention }
        guard let snapshot else { return .unknown }
        if snapshot.findings.contains(where: { $0.severity == .critical }) { return .critical }
        if snapshot.findings.contains(where: { $0.severity == .warning }) { return .warning }
        return .healthy
    }

    var color: Color {
        switch self {
        case .healthy: .green
        case .warning: .yellow
        case .critical: .red
        case .attention: .orange
        case .unknown: .gray
        }
    }

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "Warning"
        case .critical: "Critical"
        case .attention: "Needs Access"
        case .unknown: "Unscanned"
        }
    }

    var symbol: String {
        switch self {
        case .healthy: "checkmark.seal.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .attention: "lock.trianglebadge.exclamationmark"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Compact "what is this project" badge: icon + type label.
struct ProjectKindBadge: View {
    var identity: ProjectIdentity
    var compact: Bool = false

    var body: some View {
        Label(compact ? identity.kind.shortLabel : identity.kind.rawValue, systemImage: identity.kind.symbolName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(identity.kind.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(identity.kind.tint)
    }
}

/// Traffic-light pill.
struct HealthPill: View {
    var health: ProjectHealth

    var body: some View {
        Label(health.label, systemImage: health.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(health.color.opacity(0.18), in: Capsule())
            .foregroundStyle(health.color)
    }
}

/// Read-only Git summary chip.
struct GitChip: View {
    var git: GitStatus

    var body: some View {
        if git.isRepository {
            HStack(spacing: 6) {
                Image(systemName: git.isDetached ? "arrow.triangle.branch" : "arrow.branch")
                Text(git.branchDisplay)
                if !git.isClean {
                    Text("• \(git.totalChanges)Δ")
                        .foregroundStyle(.orange)
                }
                if git.hasUpstream, git.ahead > 0 || git.behind > 0 {
                    Text("↑\(git.ahead) ↓\(git.behind)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        } else {
            Label("No Git", systemImage: "arrow.branch")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
    }
}

struct ExplanationCard: View {
    var title: String
    var what: String
    var why: String
    var next: String
    var safety: String
    var example: String = ""
    var symbol: String = "info.circle"
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("Guide")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(tint)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                ExplanationItem(label: "What this is", text: what)
                ExplanationItem(label: "Why it matters", text: why)
                ExplanationItem(label: "Next action", text: next)
                ExplanationItem(label: "Safety", text: safety)
            }
            if !example.isEmpty {
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExplanationItem: View {
    var label: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
