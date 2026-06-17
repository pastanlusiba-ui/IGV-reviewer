import SwiftUI

enum AIConnectionsPresentation {
    case onboarding
    case settings
}

struct AIConnectionsManagerView: View {
    @EnvironmentObject private var appState: AppState

    let presentation: AIConnectionsPresentation

    @State private var selectedProvider: AIProvider = .openAI
    @State private var selectedMode: AIConnectionMode = .managedAccess
    @State private var connectionLabel = ""
    @State private var apiKey = ""
    @State private var localError: String?
    @State private var runningTests: Set<UUID> = []
    @State private var testResults: [UUID: ProviderConnectionTestResult] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introCard
                    addConnectionCard
                    connectionsCard
                    providerTestingCard
                    disclaimerCard
                }
                .padding(24)
            }

            if presentation == .onboarding {
                footer
            }
        }
        .frame(minWidth: 900, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation == .onboarding ? "Connect Your AI Providers" : "AI Connections")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(
                        presentation == .onboarding
                            ? "Connect one or more providers, choose app-managed access or your own API key, and change this later anytime."
                            : "Manage your AI providers in one place. You can connect more than one provider and change this later."
                    )
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.93, blue: 0.84), Color(red: 0.89, green: 0.95, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How would you like to connect AI?")
                .font(.title3.weight(.semibold))

            Text("The app can either use app-managed access where we support it, or you can bring your own API keys for stronger limits and direct provider billing.")
                .foregroundStyle(.secondary)

            Picker("Connection Mode", selection: $selectedMode) {
                ForEach(AIConnectionMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var addConnectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Provider")
                .font(.title3.weight(.semibold))

            Picker("Provider", selection: $selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(selectedProvider.shortDescription)
                    .foregroundStyle(.secondary)
                Text(selectedProvider.pricingHeadline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Connection label", text: $connectionLabel)
                .textFieldStyle(.roundedBorder)

            if selectedMode == .ownAPIKey {
                SecureField("Paste API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(selectedProvider.managedAccessNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let localError {
                Text(localError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                addConnection()
            } label: {
                Label("Add Connection", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var connectionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Providers")
                .font(.title3.weight(.semibold))

            if appState.aiConnections.isEmpty {
                Text("No providers connected yet. You can finish setup now and add providers later, or connect one or more providers before continuing.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.aiConnections) { connection in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(connection.label)
                                .font(.headline)
                            Text(connection.provider.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                StatusBadge(
                                    text: connection.modeLabel,
                                    tint: connection.mode == .ownAPIKey ? .blue : .green
                                )
                                if connection.mode == .ownAPIKey {
                                    StatusBadge(
                                        text: appState.hasStoredKey(for: connection) ? "Key saved" : "Missing key",
                                        tint: appState.hasStoredKey(for: connection) ? .green : .red
                                    )
                                }
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            appState.removeAIConnection(connection)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }

                    if connection.id != appState.aiConnections.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Important Disclaimer")
                .font(.title3.weight(.semibold))

            Text("Free or app-managed access can be useful for trying features quickly, but it may be slower, rate-limited, temporarily unavailable, or restricted to smaller models.")
            Text("Paid APIs usually give you better uptime, higher limits, faster processing, clearer provider billing, newer models, and cleaner privacy separation for your workspace.")
            Text("Provider reality today is not identical across vendors: Gemini often has an official free-tier path, while OpenAI, Perplexity, and DeepSeek generally rely on paid credits or managed access supplied by the app or organization.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var providerTestingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Connected Providers")
                .font(.title3.weight(.semibold))

            Text("Run a lightweight connectivity check before using a provider in screening or full-text review. This only checks that the API path is reachable with the saved key.")
                .foregroundStyle(.secondary)

            if appState.aiConnections.isEmpty {
                Text("Add at least one provider first.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.aiConnections) { connection in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(connection.label)
                                    .font(.headline)
                                Text(connection.provider.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(runningTests.contains(connection.id) ? "Testing..." : "Test Connection") {
                                runConnectionTest(for: connection)
                            }
                            .buttonStyle(.bordered)
                            .disabled(runningTests.contains(connection.id))
                        }

                        if let result = testResults[connection.id] {
                            StatusBadge(
                                text: result.isSuccess ? "Passed" : "Needs Attention",
                                tint: result.isSuccess ? .green : .orange
                            )
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if connection.id != appState.aiConnections.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack {
            Button("Skip for Now") {
                appState.completeAISetup()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Finish Setup") {
                appState.completeAISetup()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private func addConnection() {
        localError = nil

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedMode == .ownAPIKey && trimmedKey.isEmpty {
            localError = "Enter an API key before adding this provider."
            return
        }

        appState.addAIConnection(
            provider: selectedProvider,
            mode: selectedMode,
            label: connectionLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: trimmedKey
        )

        connectionLabel = ""
        apiKey = ""
    }

    private func runConnectionTest(for connection: AIConnection) {
        runningTests.insert(connection.id)

        Task {
            let result = await LiveAISuggestionService.testConnection(
                connection: connection,
                apiKeyLookup: { candidate in
                    appState.storedAPIKey(for: candidate)
                }
            )

            await MainActor.run {
                runningTests.remove(connection.id)
                testResults[connection.id] = result
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}
