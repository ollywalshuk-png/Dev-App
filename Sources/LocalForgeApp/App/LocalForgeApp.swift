import AppKit
import LocalForgeCore
import SwiftUI

@main
struct LocalForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workspaceStore = WorkspaceStore()

    var body: some Scene {
        WindowGroup("LocalForge", id: "main") {
            ContentView(store: workspaceStore)
                .frame(minWidth: 1180, minHeight: 720)
                .preferredColorScheme(workspaceStore.themePreferences.colorScheme)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Repository...") {
                    workspaceStore.openRepositoryPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Rescan Active Project") {
                    Task { await workspaceStore.rescanSelectedProject() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(store: workspaceStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension ThemePreferences {
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system:
            nil
        case .dark:
            .dark
        case .light:
            .light
        }
    }
}
