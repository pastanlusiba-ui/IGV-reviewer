import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case aiConnections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .aiConnections:
            return "AI Connections"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .aiConnections:
            return "bolt.badge.automatic.fill"
        }
    }
}

struct AppSettingsView: View {
    @State private var selection: SettingsSection? = .aiConnections

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .navigationTitle("Settings")
        } detail: {
            switch selection ?? .general {
            case .general:
                GeneralSettingsPane()
            case .aiConnections:
                AIConnectionsManagerView(presentation: .settings)
            }
        }
        .frame(minWidth: 980, minHeight: 760)
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("General")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Core app preferences and orientation live here. AI provider management stays in the separate AI Connections section.")
                        .foregroundStyle(.secondary)
                }

                themePreferencesCard
                syncAccountCard
                localStorageCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.refreshLocalCacheSize()
        }
    }

    private var themePreferencesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme & Preferences")
                .font(.title3.weight(.semibold))

            Picker("Appearance", selection: $appState.appearancePreference) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Use compact project cards", isOn: $appState.useCompactProjectCards)

            Text("Appearance changes apply across the desktop app. Compact project cards make the project browser denser for large review portfolios.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var syncAccountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sync & Account")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text("Account")
                        .foregroundStyle(.secondary)
                    if let currentUser = appState.currentUser {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentUser.name)
                            Text(currentUser.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not signed in")
                    }
                }

                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Text(appState.isAuthenticated ? "Connected to sync backend" : "Local mode only")
                }
            }

            Divider()

            Toggle("Sync projects when the app launches", isOn: $appState.syncOnLaunch)
            Toggle("Allow background sync checks", isOn: $appState.backgroundSyncEnabled)

            HStack {
                Text("Sync interval")
                Spacer()
                Stepper(value: $appState.syncIntervalMinutes, in: 5...60, step: 5) {
                    Text("\(appState.syncIntervalMinutes) minutes")
                        .monospacedDigit()
                }
                .frame(maxWidth: 220, alignment: .trailing)
            }

            HStack {
                Button("Refresh Now") {
                    Task { await appState.refreshProjects() }
                }
                .buttonStyle(.bordered)
                .disabled(!appState.isAuthenticated)

                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.isAuthenticated)
            }

            Text("These values are stored now and will guide the sync engine behavior as collaborative syncing is completed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var localStorageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local Storage & Cache")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text("Cache size")
                        .foregroundStyle(.secondary)
                    Text(appState.localCacheSize)
                        .monospacedDigit()
                }

                GridRow {
                    Text("Cache location")
                        .foregroundStyle(.secondary)
                    Text(appState.localCachePath())
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            Divider()

            Toggle("Keep PDFs available for offline use", isOn: $appState.offlinePDFCachingEnabled)

            HStack {
                Text("Cache retention")
                Spacer()
                Stepper(value: $appState.cacheRetentionDays, in: 1...180, step: 1) {
                    Text("\(appState.cacheRetentionDays) days")
                        .monospacedDigit()
                }
                .frame(maxWidth: 220, alignment: .trailing)
            }

            HStack {
                Button("Refresh Cache Size") {
                    appState.refreshLocalCacheSize()
                }
                .buttonStyle(.bordered)

                Button("Clear Local Cache") {
                    appState.clearLocalCache()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Clearing the cache only removes app-side cached files. Saved API keys remain in Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private func settingsCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(body)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}
