import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.89),
                    Color(red: 0.88, green: 0.93, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("2IGV")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.brown)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Human-led evidence review, with AI where it helps.")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Plan reviews, screen studies, manage full texts, extract evidence, synthesize results, and draft reports with shared project workflows that keep human judgement in charge.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 560, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow("Human reviewers stay accountable for decisions")
                        featureRow("AI supports screening, drafting, and summaries")
                        featureRow("Desktop workflow with shared collaboration and sync")
                    }

                    HStack(spacing: 14) {
                        Button(primaryButtonTitle) {
                            appState.continueFromHomeScreen()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Settings") {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 18) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 54, style: .continuous))
                        .shadow(color: .black.opacity(0.10), radius: 30, y: 12)

                    Text("AI-assisted systematic review workspace")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 56)
        }
        .frame(minWidth: 1180, minHeight: 780)
    }

    private var primaryButtonTitle: String {
        appState.hasCompletedAISetup ? "Continue to Sign In" : "Start Setup"
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.brown)
            Text(text)
                .font(.headline)
        }
    }
}
