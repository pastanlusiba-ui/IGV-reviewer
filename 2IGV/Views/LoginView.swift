import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var email = "pastan@example.com"
    @State private var password = "password"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.97, blue: 0.92), Color(red: 0.89, green: 0.94, blue: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 124, height: 124)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                    Text("2IGV")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Desktop evidence review with shared sync and AI automation")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                VStack(alignment: .leading, spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage = appState.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await appState.signIn(email: email, password: password) }
                    } label: {
                        if appState.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
                .frame(width: 420)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(40)
        }
        .frame(minWidth: 1100, minHeight: 760)
    }
}
