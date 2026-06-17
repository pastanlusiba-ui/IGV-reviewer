import AppKit
import SwiftUI

@main
struct IGVReviewerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.preferredColorScheme)
        }
        .windowStyle(.titleBar)

        Settings {
            AppSettingsView()
                .environmentObject(appState)
                .preferredColorScheme(appState.preferredColorScheme)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Button("Refresh Projects") {
                    Task { await appState.refreshProjects() }
                }
                .disabled(!appState.isAuthenticated)

                Button("Sign Out") {
                    appState.signOut()
                }
                .disabled(!appState.isAuthenticated)
            }
        }
    }
}
