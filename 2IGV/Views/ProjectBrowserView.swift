import SwiftUI

struct ProjectBrowserView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var isShowingCreateProject = false

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { appState.selectedProjectID },
                set: { newValue in
                    guard let newValue else { return }
                    Task { await appState.loadProjectDetail(projectID: newValue) }
                })
            ) {
                ForEach(appState.projects) { project in
                    VStack(alignment: .leading, spacing: appState.useCompactProjectCards ? 6 : 8) {
                        HStack {
                            Text(project.title)
                                .font(.headline)
                            Spacer()
                            StatusBadge(
                                text: project.health.label,
                                tint: tint(for: project.health)
                            )
                        }
                        Text(project.reviewQuestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            Text(project.stage.label)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("\(Int(project.progress * 100))%")
                                .font(.caption.monospacedDigit())
                        }
                    }
                    .padding(.vertical, appState.useCompactProjectCards ? 4 : 8)
                    .tag(project.id)
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingCreateProject = true
                    } label: {
                        Label("New Project", systemImage: "plus.circle.fill")
                    }
                    .help("Create a new human-led review project")
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        openSettings()
                    } label: {
                        Label("AI Connections", systemImage: "gearshape.2.fill")
                    }
                    .help("Open AI Connections in Settings")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await appState.refreshProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh projects")
                }
            }
        } detail: {
            if let project = appState.selectedProject {
                ProjectDashboardView(project: project)
            } else if appState.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading project...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "rectangle.stack.person.crop",
                    description: Text("Select a project to review its team, status, and active automation jobs.")
                )
            }
        }
        .sheet(isPresented: $isShowingCreateProject) {
            ProjectEditorView(mode: .create) { draft in
                appState.createProject(from: draft)
            }
        }
    }

    private func tint(for health: ProjectHealth) -> Color {
        switch health {
        case .onTrack:
            return .green
        case .atRisk:
            return .orange
        case .blocked:
            return .red
        }
    }
}
