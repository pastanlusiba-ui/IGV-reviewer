import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if appState.showPostLoginScreen {
                    PostLoginWelcomeView()
                } else {
                    ProjectBrowserView()
                }
            } else if appState.showHomeScreen {
                HomeView()
            } else if !appState.hasCompletedAISetup {
                AISetupOnboardingView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.2), value: appState.hasCompletedAISetup)
    }
}
