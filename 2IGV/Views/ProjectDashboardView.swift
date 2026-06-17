import SwiftUI

struct ProjectDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    let project: ProjectDetail
    @State private var isShowingProjectSettings = false
    @State private var isShowingSearchWorkspace = false
    @State private var isShowingScreeningWorkspace = false
    @State private var isShowingFullTextWorkspace = false
    @State private var isShowingExtractionWorkspace = false
    @State private var isShowingSynthesisWorkspace = false
    @State private var isShowingReportWorkspace = false
    @State private var isShowingCollaboratorManager = false
    @State private var conflictUnderReview: WorkspaceSyncNotice?
    @State private var stageAccessMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let syncNotice = appState.workspaceSyncNotice(for: project.id) {
                    syncNoticePanel(syncNotice)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(title: "Stage", value: project.stage.label, tint: .blue)
                    MetricCard(title: "References", value: "\(project.referencesCount)", tint: .green)
                    MetricCard(title: "Collaborators", value: "\(project.collaboratorsCount)", tint: .orange)
                }

                HStack(alignment: .top, spacing: 20) {
                    projectOverview
                    teamPanel
                }

                reviewProcessBoard
                searchPanel
                screeningPanel
                fullTextPanel
                extractionPanel
                synthesisPanel
                reportPanel
                automationPanel
                humanGuidancePanel
                aiConnectionsPanel
                actionPanel
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isShowingProjectSettings) {
            ProjectEditorView(mode: .edit, draft: ProjectDraft(project: project)) { draft in
                appState.updateProject(projectID: project.id, from: draft)
            }
        }
        .sheet(isPresented: $isShowingSearchWorkspace) {
            ProjectSearchWorkspaceView(project: project)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingScreeningWorkspace) {
            ProjectScreeningWorkspaceView(project: project)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingFullTextWorkspace) {
            ProjectFullTextWorkspaceView(project: project, allowedStages: fullTextAllowedStages)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingExtractionWorkspace) {
            ProjectExtractionWorkspaceView(project: project)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingSynthesisWorkspace) {
            ProjectSynthesisWorkspaceView(project: project)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingReportWorkspace) {
            ProjectReportWorkspaceView(project: project)
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingCollaboratorManager) {
            ProjectCollaboratorManagementView(project: project) { draft in
                appState.updateProject(projectID: project.id, from: draft)
            }
            .environmentObject(appState)
        }
        .sheet(item: $conflictUnderReview) { notice in
            WorkspaceConflictReviewView(project: project, notice: notice)
                .environmentObject(appState)
        }
        .alert(
            "Stage Not Assigned",
            isPresented: Binding(
                get: { stageAccessMessage != nil },
                set: { if !$0 { stageAccessMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                stageAccessMessage = nil
            }
        } message: {
            Text(stageAccessMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(project.reviewQuestion)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Project Settings") {
                    isShowingProjectSettings = true
                }
                .buttonStyle(.bordered)
                StatusBadge(text: project.health.label, tint: healthTint)
            }

            ProgressView(value: project.progress)
                .tint(.brown)

            HStack(spacing: 12) {
                Label(project.teamName, systemImage: "person.3.fill")
                Label(project.lead.name, systemImage: "star.fill")
                Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.92, green: 0.88, blue: 0.78), Color(red: 0.82, green: 0.89, blue: 0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var reviewProcessBoard: some View {
        let workspace = appState.searchWorkspace(for: project)
        let screeningCounts = workspace.screeningCounts
        let extractionCounts = workspace.extractionCompletionCounts
        let flowCards = [
            FlowMetric(title: "Identification", value: "\(workspace.importedReferences.count)", note: "Records", tint: Color(red: 0.86, green: 0.53, blue: 0.12)),
            FlowMetric(title: "Screening", value: "\(screeningCounts.included)", note: "Included at TA", tint: Color(red: 0.77, green: 0.14, blue: 0.11)),
            FlowMetric(title: "Included", value: "\(extractionCounts.eligible)", note: "Ready for extraction", tint: Color(red: 0.22, green: 0.49, blue: 0.14))
        ]
        let stageButtons = reviewStageButtons(for: workspace)

        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Process")
                    .font(.title2.weight(.bold))
                Text("Move through the workflow using the stage buttons below. Each stage remains human-led, with AI available only where it supports the review team.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Text("PRISMA Flow")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ForEach(Array(flowCards.enumerated()), id: \.offset) { index, card in
                    FlowMetricCard(metric: card)
                    if index < flowCards.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18)
            ], spacing: 18) {
                ForEach(stageButtons) { stage in
                    Button {
                        stage.action()
                    } label: {
                        ReviewStageButton(stage: stage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.33, green: 0.28, blue: 0.23).opacity(0.08),
                            Color(red: 0.88, green: 0.71, blue: 0.39).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(red: 0.29, green: 0.20, blue: 0.14).opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func syncNoticePanel(_ notice: WorkspaceSyncNotice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shared Changes Need Review")
                        .font(.title3.weight(.semibold))
                    Text(notice.message)
                        .foregroundStyle(.secondary)
                    Text(
                        "Latest shared copy: version \(notice.serverVersion) • \(notice.editorName ?? "Another collaborator") • \(notice.serverUpdatedAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reload Shared Copy") {
                    Task {
                        await appState.reloadSharedWorkspace(projectID: project.id)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Review Differences") {
                    conflictUnderReview = notice
                }
                .buttonStyle(.bordered)
                Button("Keep Local for Now") {
                    appState.clearWorkspaceSyncNotice(for: project.id)
                }
                .buttonStyle(.bordered)
            }
            Text("A human should compare the shared version before continuing to edit the project.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var projectOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Overview")
                .font(.title3.weight(.semibold))
            overviewRow(title: "Lead", value: "\(project.lead.name) • \(project.lead.title)")
            overviewRow(title: "Current Stage", value: project.stage.label)
            overviewRow(title: "Completion", value: "\(Int(project.progress * 100))%")
            overviewRow(title: "Last Updated", value: project.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
    }

    private var teamPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Collaborators")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Manage") {
                    isShowingCollaboratorManager = true
                }
                .buttonStyle(.bordered)
            }
            ForEach(project.members.indices, id: \.self) { index in
                TeamMemberRow(
                    member: project.members[index],
                    stageText: stageSummary(for: project.members[index])
                )
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
    }

    private var automationPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automation Jobs")
                .font(.title3.weight(.semibold))

            if project.automations.isEmpty {
                Text("No automation jobs have been created yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.automations) { job in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(job.title)
                                .font(.headline)
                            Text("Provider: \(job.provider)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            StatusBadge(text: job.status.rawValue.capitalized, tint: jobTint(job.status))
                            Text(job.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if job.id != project.automations.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var searchPanel: some View {
        let workspace = appState.searchWorkspace(for: project)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search & Import")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Search Stage") {
                    openStage(.searching)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Build and approve the search strategy before screening. Imported references stay reviewable by humans, with AI available only as support.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Concepts", value: "\(workspace.searchConcepts.count)")
                overviewRow(title: "Databases", value: "\(workspace.databaseSearches.count)")
                overviewRow(title: "Imported", value: "\(workspace.importedReferences.count)")
            }

            if workspace.importedReferences.isEmpty {
                Text("No references imported yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest imported titles")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(workspace.importedReferences.suffix(3).reversed(), id: \.id) { reference in
                        Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Next Actions")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Search & Import") {
                    openStage(.searching)
                }
                .buttonStyle(.bordered)
                Button("Screening") {
                    openStage(.screening)
                }
                .buttonStyle(.bordered)
                Button("Full Text") {
                    openFullTextStage()
                }
                .buttonStyle(.bordered)
                Button("Extraction") {
                    openStage(.dataExtraction)
                }
                .buttonStyle(.bordered)
                Button("Synthesis") {
                    openStage(.synthesisQA)
                }
                .buttonStyle(.bordered)
                Button("Report") {
                    openStage(.report)
                }
                .buttonStyle(.bordered)
                Button("Edit Project") {
                    isShowingProjectSettings = true
                }
                .buttonStyle(.bordered)
            }
            ForEach(project.nextActions, id: \.self) { action in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .foregroundStyle(.brown)
                    Text(action)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func reviewStageButtons(for workspace: SearchWorkspace) -> [ReviewStage] {
        [
            ReviewStage(
                title: "1. Searching",
                processStage: .searching,
                subtitle: "\(workspace.searchConcepts.count) concepts • \(workspace.databaseSearches.count) database plans",
                systemImage: "magnifyingglass",
                colors: [Color(red: 0.95, green: 0.66, blue: 0.12), Color(red: 0.79, green: 0.38, blue: 0.06)],
                pattern: .chevrons,
                assignedCount: assignedCount(for: .searching),
                isAccessible: canAccess(.searching),
                action: { openStage(.searching) }
            ),
            ReviewStage(
                title: "2. Screening",
                processStage: .screening,
                subtitle: "\(workspace.screeningCounts.pending) pending • \(workspace.screeningCounts.conflicts) conflicts",
                systemImage: "doc.text.magnifyingglass",
                colors: [Color(red: 0.96, green: 0.22, blue: 0.15), Color(red: 0.69, green: 0.12, blue: 0.10)],
                pattern: .zigzag,
                assignedCount: assignedCount(for: .screening),
                isAccessible: canAccess(.screening),
                action: { openStage(.screening) }
            ),
            ReviewStage(
                title: "3. Full Text Retrieval",
                processStage: .fullTextRetrieval,
                subtitle: "\(workspace.fullTextRetrievalCounts.attached) PDFs attached",
                systemImage: "doc.fill",
                colors: [Color(red: 0.56, green: 0.34, blue: 0.13), Color(red: 0.25, green: 0.15, blue: 0.10)],
                pattern: .bands,
                assignedCount: assignedCount(for: .fullTextRetrieval),
                isAccessible: canAccess(.fullTextRetrieval),
                action: { openStage(.fullTextRetrieval) }
            ),
            ReviewStage(
                title: "4. Full Text Screening",
                processStage: .fullTextScreening,
                subtitle: "\(workspace.fullTextCounts.pending) pending • \(workspace.fullTextCounts.conflicts) conflicts",
                systemImage: "checklist",
                colors: [Color(red: 0.97, green: 0.69, blue: 0.21), Color(red: 0.90, green: 0.33, blue: 0.11)],
                pattern: .triangles,
                assignedCount: assignedCount(for: .fullTextScreening),
                isAccessible: canAccess(.fullTextScreening),
                action: { openStage(.fullTextScreening) }
            ),
            ReviewStage(
                title: "5. Data Extraction",
                processStage: .dataExtraction,
                subtitle: "\(workspace.extractionCompletionCounts.completed)/\(max(1, workspace.extractionCompletionCounts.eligible)) completed",
                systemImage: "tablecells",
                colors: [Color(red: 0.30, green: 0.58, blue: 0.15), Color(red: 0.14, green: 0.37, blue: 0.09)],
                pattern: .gridSteps,
                assignedCount: assignedCount(for: .dataExtraction),
                isAccessible: canAccess(.dataExtraction),
                action: { openStage(.dataExtraction) }
            ),
            ReviewStage(
                title: "6. Synthesis & QA",
                processStage: .synthesisQA,
                subtitle: "\(workspace.synthesizedFieldCount) syntheses • \(workspace.extractionCompletionCounts.qaStarted) QA started",
                systemImage: "shield.checkered",
                colors: [Color(red: 0.79, green: 0.45, blue: 0.08), Color(red: 0.43, green: 0.22, blue: 0.09)],
                pattern: .chevrons,
                assignedCount: assignedCount(for: .synthesisQA),
                isAccessible: canAccess(.synthesisQA),
                action: { openStage(.synthesisQA) }
            ),
            ReviewStage(
                title: "7. Report Writing",
                processStage: .report,
                subtitle: "\(workspace.reportSectionCompletionCount) sections drafted",
                systemImage: "square.and.pencil",
                colors: [Color(red: 0.84, green: 0.18, blue: 0.10), Color(red: 0.38, green: 0.10, blue: 0.08)],
                pattern: .zigzag,
                assignedCount: assignedCount(for: .report),
                isAccessible: canAccess(.report),
                action: { openStage(.report) }
            )
        ]
    }

    private var screeningPanel: some View {
        let workspace = appState.searchWorkspace(for: project)
        let counts = workspace.screeningCounts

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Title & Abstract Screening")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Screening") {
                    openStage(.screening)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Keep this stage reviewer-led. AI can suggest, but humans should confirm includes, excludes, and conflicts before the review progresses.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Pending", value: "\(counts.pending)")
                overviewRow(title: "Included", value: "\(counts.included)")
                overviewRow(title: "Conflicts", value: "\(counts.conflicts)")
            }

            if workspace.importedReferences.isEmpty {
                Text("No imported references available yet. Complete Search & Import first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !workspace.hasScreeningActivity {
                Text("Screening has not started yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if counts.conflicts > 0 {
                Text("\(counts.conflicts) conflict(s) need explicit human resolution.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Human and AI screening activity has been recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var fullTextPanel: some View {
        let workspace = appState.searchWorkspace(for: project)
        let retrieval = workspace.fullTextRetrievalCounts
        let counts = workspace.fullTextCounts

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Full Text Review")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Full Text") {
                    openFullTextStage()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Retrieve or attach PDFs first, then let reviewers make the final full-text inclusion decision. Conflicts should stay visible until a person resolves them.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Eligible", value: "\(retrieval.eligible)")
                overviewRow(title: "PDFs", value: "\(retrieval.attached)")
                overviewRow(title: "FT Conflicts", value: "\(counts.conflicts)")
            }

            if retrieval.eligible == 0 {
                Text("No studies have advanced to full-text review yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !workspace.hasFullTextActivity {
                Text("Full-text retrieval and screening have not started yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if counts.conflicts > 0 {
                Text("\(counts.conflicts) full-text conflict(s) need human resolution.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Full-text activity has been recorded for this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var aiConnectionsPanel: some View {
        AIConnectionsPanelView(
            connections: appState.aiConnections,
            hasStoredKey: { connection in
                appState.hasStoredKey(for: connection)
            },
            onManage: {
                openSettings()
            }
        )
        .padding(20)
        .background(cardBackground)
    }

    private var extractionPanel: some View {
        let workspace = appState.searchWorkspace(for: project)
        let counts = workspace.extractionCompletionCounts

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Data Extraction & QA")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Extraction") {
                    openStage(.dataExtraction)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Reviewers should capture the extracted values and evidence excerpts directly. AI can support later drafting, but it should not silently author the final study record.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Eligible", value: "\(counts.eligible)")
                overviewRow(title: "Extracted", value: "\(counts.completed)")
                overviewRow(title: "QA Started", value: "\(counts.qaStarted)")
            }

            if counts.eligible == 0 {
                Text("No studies are ready for extraction yet. Complete full-text inclusion first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !workspace.hasExtractionActivity {
                Text("Extraction has not started yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if counts.completed < counts.eligible || counts.qaStarted < counts.eligible {
                Text("Some included studies still need extraction or QA work.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Extraction and quality appraisal have been recorded for all included studies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var humanGuidancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Human & AI Roles")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Human review policy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(project.humanReviewPolicy ?? "Humans remain the final decision-makers for review outcomes.")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("AI assistance policy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(project.aiAssistPolicy ?? "AI is used to assist with summarization, drafting, and suggestions under human supervision.")
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var synthesisPanel: some View {
        let workspace = appState.searchWorkspace(for: project)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Synthesis")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Synthesis") {
                    openStage(.synthesisQA)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Use extracted values and evidence excerpts to draft variable-level syntheses. Interpretation should still sit with the review team.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Variables", value: "\(workspace.allFlatFields.count)")
                overviewRow(title: "Synthesized", value: "\(workspace.synthesizedFieldCount)")
                overviewRow(title: "Included Studies", value: "\(workspace.eligibleForExtractionCount)")
            }

            if !workspace.hasExtractionActivity {
                Text("Synthesis usually starts after extraction has begun.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !workspace.hasSynthesisActivity {
                Text("Synthesis drafting has not started yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Variable-level synthesis drafts are available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var reportPanel: some View {
        let workspace = appState.searchWorkspace(for: project)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Report Writing")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Open Report") {
                    openStage(.report)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Draft the report with synthesis notes visible, then export only after a human final review.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewRow(title: "Sections Drafted", value: "\(workspace.reportSectionCompletionCount)")
                overviewRow(title: "Syntheses", value: "\(workspace.synthesizedFieldCount)")
                overviewRow(title: "Stage", value: project.stage.label)
            }

            if !workspace.hasSynthesisActivity {
                Text("Report writing is best started after synthesis drafts exist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !workspace.hasReportDraftActivity {
                Text("Report drafting has not started yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Report content is being drafted in this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func overviewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private var healthTint: Color {
        switch project.health {
        case .onTrack:
            return .green
        case .atRisk:
            return .orange
        case .blocked:
            return .red
        }
    }

    private func jobTint(_ status: JobStatus) -> Color {
        switch status {
        case .queued:
            return .orange
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private func openStage(_ stage: ReviewProcessStage) {
        guard canAccess(stage) else {
            stageAccessMessage = "\(appState.currentUser?.name ?? "This user") is not assigned to \(stage.label) for this project. Ask the project owner to update stage assignments in Manage Collaborators."
            return
        }

        switch stage {
        case .searching:
            isShowingSearchWorkspace = true
        case .screening:
            isShowingScreeningWorkspace = true
        case .fullTextRetrieval, .fullTextScreening:
            isShowingFullTextWorkspace = true
        case .dataExtraction:
            isShowingExtractionWorkspace = true
        case .synthesisQA:
            isShowingSynthesisWorkspace = true
        case .report:
            isShowingReportWorkspace = true
        }
    }

    private func openFullTextStage() {
        if canAccess(.fullTextRetrieval) {
            openStage(.fullTextRetrieval)
        } else {
            openStage(.fullTextScreening)
        }
    }

    private func canAccess(_ stage: ReviewProcessStage) -> Bool {
        guard let member = currentProjectMember else {
            return appState.currentUser == nil
        }

        if member.role == .owner {
            return true
        }

        return member.assignedStages.contains(stage)
    }

    private var fullTextAllowedStages: Set<ReviewProcessStage> {
        var stages = Set<ReviewProcessStage>()
        if canAccess(.fullTextRetrieval) {
            stages.insert(.fullTextRetrieval)
        }
        if canAccess(.fullTextScreening) {
            stages.insert(.fullTextScreening)
        }
        return stages
    }

    private func assignedCount(for stage: ReviewProcessStage) -> Int {
        project.members.filter { member in
            member.role == .owner || member.assignedStages.contains(stage)
        }.count
    }

    private func stageSummary(for member: MemberSummary) -> String {
        if member.role == .owner {
            return "All review stages"
        }

        if member.assignedStages.isEmpty {
            return "No review stages assigned"
        }

        return member.assignedStages.map(\.shortLabel).joined(separator: ", ")
    }

    private var currentProjectMember: MemberSummary? {
        guard let user = appState.currentUser else { return nil }

        if let member = project.members.first(where: { member in
            member.id == user.id || (member.email?.lowercased() ?? "") == user.email.lowercased()
        }) {
            return member
        }

        if project.lead.id == user.id || project.lead.email.lowercased() == user.email.lowercased() {
            return MemberSummary(
                id: project.lead.id,
                name: project.lead.name,
                email: project.lead.email,
                role: .owner,
                assignedStages: ReviewProcessStage.allCases
            )
        }

        return nil
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FlowMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let note: String
    let tint: Color
}

private struct TeamMemberRow: View {
    let member: MemberSummary
    let stageText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)
                if let email = member.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stageText)
                    .font(.caption2)
                    .foregroundStyle(member.role == .owner || !member.assignedStages.isEmpty ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.brown)
        }
    }
}

private struct ReviewStage: Identifiable {
    let id = UUID()
    let title: String
    let processStage: ReviewProcessStage
    let subtitle: String
    let systemImage: String
    let colors: [Color]
    let pattern: ReviewStagePatternStyle
    let assignedCount: Int
    let isAccessible: Bool
    let action: () -> Void
}

private enum ReviewStagePatternStyle {
    case chevrons
    case zigzag
    case bands
    case triangles
    case gridSteps
}

private struct FlowMetricCard: View {
    let metric: FlowMetric

    var body: some View {
        VStack(spacing: 6) {
            Text(metric.title.uppercased())
                .font(.caption.weight(.bold))
            Text(metric.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(metric.note)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 138, height: 104)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(metric.tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(metric.tint.opacity(0.75), lineWidth: 1.5)
        )
        .shadow(color: metric.tint.opacity(0.12), radius: 10, y: 5)
    }
}

private struct ReviewStageButton: View {
    let stage: ReviewStage

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: stage.systemImage)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(stage.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(stage.subtitle)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.99, green: 0.94, blue: 0.84).opacity(0.95))
            HStack(spacing: 6) {
                Image(systemName: stage.isAccessible ? "person.crop.circle.badge.checkmark" : "lock.fill")
                Text(stage.isAccessible ? "\(stage.assignedCount) assigned" : "Not assigned to you")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(stage.isAccessible ? Color.white.opacity(0.18) : Color.black.opacity(0.24))
            )
        }
        .foregroundStyle(Color(red: 1.00, green: 0.97, blue: 0.90))
        .frame(maxWidth: .infinity)
        .frame(height: 158)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: stage.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .trailing) {
            ReviewStagePattern(style: stage.pattern)
                .frame(width: 132, height: 110)
                .padding(.trailing, 14)
                .opacity(stage.isAccessible ? 0.28 : 0.12)
                .blendMode(.screen)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(red: 1.00, green: 0.90, blue: 0.66).opacity(0.28), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 10)
    }
}

private struct ReviewStagePattern: View {
    let style: ReviewStagePatternStyle

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let stroke = Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.95)
                let accent = Color(red: 0.26, green: 0.13, blue: 0.09).opacity(0.65)

                switch style {
                case .chevrons:
                    for offset in stride(from: 8.0, to: size.height, by: 22.0) {
                        var path = Path()
                        path.move(to: CGPoint(x: 12, y: offset))
                        path.addLine(to: CGPoint(x: 42, y: offset - 12))
                        path.addLine(to: CGPoint(x: 72, y: offset))
                        path.addLine(to: CGPoint(x: 102, y: offset - 12))
                        context.stroke(path, with: .color(stroke), lineWidth: 5)
                    }
                case .zigzag:
                    for index in 0..<4 {
                        let baseX = 18.0 + Double(index) * 24.0
                        var path = Path()
                        path.move(to: CGPoint(x: baseX, y: 12))
                        path.addLine(to: CGPoint(x: baseX + 14, y: 28))
                        path.addLine(to: CGPoint(x: baseX, y: 44))
                        path.addLine(to: CGPoint(x: baseX + 14, y: 60))
                        path.addLine(to: CGPoint(x: baseX, y: 76))
                        path.addLine(to: CGPoint(x: baseX + 14, y: 92))
                        context.stroke(path, with: .color(stroke), lineWidth: 5)
                    }
                case .bands:
                    for index in 0..<5 {
                        let inset = Double(index) * 10.0
                        let rect = CGRect(x: 14 + inset, y: 14 + inset * 0.45, width: 96 - inset * 1.2, height: 10)
                        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(index.isMultiple(of: 2) ? stroke : accent))
                    }
                case .triangles:
                    for row in 0..<3 {
                        for column in 0..<4 {
                            let originX = 14.0 + Double(column) * 24.0
                            let originY = 18.0 + Double(row) * 24.0
                            var path = Path()
                            path.move(to: CGPoint(x: originX, y: originY + 14))
                            path.addLine(to: CGPoint(x: originX + 10, y: originY))
                            path.addLine(to: CGPoint(x: originX + 20, y: originY + 14))
                            path.closeSubpath()
                            context.fill(path, with: .color((row + column).isMultiple(of: 2) ? stroke : accent))
                        }
                    }
                case .gridSteps:
                    for row in 0..<4 {
                        for column in 0...row {
                            let rect = CGRect(x: 18 + Double(column) * 18, y: 18 + Double(row) * 18, width: 12, height: 12)
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 2),
                                with: .color((row + column).isMultiple(of: 2) ? stroke : accent)
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AIConnectionsPanelView: View {
    let connections: [AIConnection]
    let hasStoredKey: (AIConnection) -> Bool
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Providers")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Manage APIs", action: onManage)
                    .buttonStyle(.bordered)
            }

            if connections.isEmpty {
                Text("No AI providers are connected yet. Add one or more providers to unlock app-managed access or your own API-key based integrations.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach<[AIConnection], UUID, AIConnectionRowView>(connections, id: \.id) { connection in
                    AIConnectionRowView(
                        connection: connection,
                        hasStoredKey: hasStoredKey(connection)
                    )
                }
            }
        }
    }
}

private struct WorkspaceConflictReviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail
    let notice: WorkspaceSyncNotice

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Compare Shared Changes")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Review your local draft against the latest shared copy before deciding what to keep.")
                    .foregroundStyle(.secondary)
                Text("Server version \(notice.serverVersion) from \(notice.editorName ?? "another collaborator") on \(notice.serverUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Color(red: 0.87, green: 0.92, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    compareCard(
                        title: "Search Setup",
                        localSummary: searchSummary(for: notice.localWorkspace),
                        serverSummary: searchSummary(for: notice.serverWorkspace)
                    )
                    compareCard(
                        title: "Imported & Reviewed Studies",
                        localSummary: referencesSummary(for: notice.localWorkspace),
                        serverSummary: referencesSummary(for: notice.serverWorkspace)
                    )
                    compareCard(
                        title: "Extraction & Synthesis",
                        localSummary: synthesisSummary(for: notice.localWorkspace),
                        serverSummary: synthesisSummary(for: notice.serverWorkspace)
                    )
                    compareCard(
                        title: "Report Drafting",
                        localSummary: reportSummary(for: notice.localWorkspace),
                        serverSummary: reportSummary(for: notice.serverWorkspace)
                    )
                }
                .padding(24)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Merge Actions")
                    .font(.headline)

                HStack {
                    Button("Use Full Server Copy") {
                        appState.resolveWorkspaceConflict(
                            projectID: project.id,
                            mergedWorkspace: notice.serverWorkspace,
                            serverVersion: notice.serverVersion,
                            serverUpdatedAt: notice.serverUpdatedAt,
                            editorName: notice.editorName
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Merge Search Setup") {
                        var merged = notice.localWorkspace
                        merged.searchConcepts = notice.serverWorkspace.searchConcepts
                        merged.databaseSearches = notice.serverWorkspace.databaseSearches
                        merged.inclusionCriteria = notice.serverWorkspace.inclusionCriteria
                        merged.exclusionCriteria = notice.serverWorkspace.exclusionCriteria
                        appState.resolveWorkspaceConflict(
                            projectID: project.id,
                            mergedWorkspace: merged,
                            serverVersion: notice.serverVersion,
                            serverUpdatedAt: notice.serverUpdatedAt,
                            editorName: notice.editorName
                        )
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Merge Imported Studies") {
                        var merged = notice.localWorkspace
                        merged.importedReferences = notice.serverWorkspace.importedReferences
                        appState.resolveWorkspaceConflict(
                            projectID: project.id,
                            mergedWorkspace: merged,
                            serverVersion: notice.serverVersion,
                            serverUpdatedAt: notice.serverUpdatedAt,
                            editorName: notice.editorName
                        )
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("Merge Draft Content") {
                        var merged = notice.localWorkspace
                        merged.variableSynthesis = notice.serverWorkspace.variableSynthesis
                        merged.reportTitleSection = notice.serverWorkspace.reportTitleSection
                        merged.reportKeywords = notice.serverWorkspace.reportKeywords
                        merged.reportAbstract = notice.serverWorkspace.reportAbstract
                        merged.reportIntroduction = notice.serverWorkspace.reportIntroduction
                        merged.reportMethods = notice.serverWorkspace.reportMethods
                        merged.reportResults = notice.serverWorkspace.reportResults
                        merged.reportDiscussion = notice.serverWorkspace.reportDiscussion
                        merged.reportReferences = notice.serverWorkspace.reportReferences
                        merged.reportAppendices = notice.serverWorkspace.reportAppendices
                        merged.reportCitationStyle = notice.serverWorkspace.reportCitationStyle
                        appState.resolveWorkspaceConflict(
                            projectID: project.id,
                            mergedWorkspace: merged,
                            serverVersion: notice.serverVersion,
                            serverUpdatedAt: notice.serverUpdatedAt,
                            editorName: notice.editorName
                        )
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Keep Local Draft") {
                        appState.clearWorkspaceSyncNotice(for: project.id)
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 1100, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func compareCard(title: String, localSummary: [String], serverSummary: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            HStack(alignment: .top, spacing: 16) {
                compareColumn(title: "Local Copy", lines: localSummary)
                compareColumn(title: "Server Copy", lines: serverSummary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func compareColumn(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func searchSummary(for workspace: SearchWorkspace) -> [String] {
        let concepts = workspace.searchConcepts
            .map { "\($0.category): \($0.term.isEmpty ? "Not set" : $0.term)" }
            .prefix(5)
        return [
            "\(workspace.searchConcepts.count) search concept(s)",
            "\(workspace.databaseSearches.count) database strategy record(s)"
        ] + concepts
    }

    private func referencesSummary(for workspace: SearchWorkspace) -> [String] {
        let counts = workspace.screeningCounts
        return [
            "\(workspace.importedReferences.count) imported reference(s)",
            "\(counts.included) included, \(counts.excluded) excluded, \(counts.conflicts) conflict(s)",
            "\(workspace.fullTextCounts.included) full-text includes"
        ]
    }

    private func synthesisSummary(for workspace: SearchWorkspace) -> [String] {
        let extraction = workspace.extractionCompletionCounts
        return [
            "\(extraction.completed)/\(extraction.eligible) extraction records completed",
            "\(workspace.synthesizedFieldCount) synthesized variable(s)",
            "\(workspace.allFlatFields.count) configured extraction variable(s)"
        ]
    }

    private func reportSummary(for workspace: SearchWorkspace) -> [String] {
        [
            "\(workspace.reportSectionCompletionCount) drafted report section(s)",
            "\(workspace.includedReferencesForReporting.count) reference(s) ready for reporting",
            "Citation style: \(workspace.reportCitationStyle.rawValue)"
        ]
    }
}

private struct AIConnectionRowView: View {
    let connection: AIConnection
    let hasStoredKey: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(connection.label)
                    .font(.headline)
                Text(connection.provider.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                StatusBadge(
                    text: connection.modeLabel,
                    tint: connection.mode == .ownAPIKey ? .blue : .green
                )
                if connection.mode == .ownAPIKey {
                    Text(hasStoredKey ? "API key saved" : "Missing key")
                        .font(.caption2)
                        .foregroundStyle(hasStoredKey ? Color.secondary : Color.red)
                }
            }
        }
    }
}
