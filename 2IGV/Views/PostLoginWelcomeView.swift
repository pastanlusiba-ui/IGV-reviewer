import SwiftUI

struct PostLoginWelcomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.90),
                    Color(red: 0.87, green: 0.92, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 144, height: 144)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                    Text("Welcome\(userNameSuffix)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Your review workspace is ready. Continue into the projects area to manage active reviews, collaborators, and AI-assisted tasks.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                HStack(spacing: 18) {
                    summaryCard(title: "Projects", value: "\(appState.projects.count)", note: "Available in your workspace")
                    summaryCard(title: "Account", value: appState.currentUser?.email ?? "Signed in", note: "Current session")
                }

                HStack(spacing: 14) {
                    Button("Open Projects") {
                        appState.continueToProjects()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Sign Out") {
                        appState.signOut()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(48)
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    private var userNameSuffix: String {
        guard let name = appState.currentUser?.name, !name.isEmpty else { return "" }
        return ", \(name)"
    }

    private func summaryCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 260, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
    }
}
