import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var showHomeScreen = true
    @Published var showPostLoginScreen = false
    @Published var hasCompletedAISetup = false
    @Published var isAuthenticated = false
    @Published var currentUser: UserSummary?
    @Published var projects: [ProjectSummary] = []
    @Published var selectedProjectID: String?
    @Published var selectedProject: ProjectDetail?
    @Published var aiConnections: [AIConnection] = []
    @Published var appearancePreference: AppearancePreference {
        didSet { preferencesStore.setAppearancePreference(appearancePreference) }
    }
    @Published var useCompactProjectCards: Bool {
        didSet { preferencesStore.setCompactProjectCards(useCompactProjectCards) }
    }
    @Published var syncOnLaunch: Bool {
        didSet { preferencesStore.setSyncOnLaunch(syncOnLaunch) }
    }
    @Published var backgroundSyncEnabled: Bool {
        didSet { preferencesStore.setBackgroundSyncEnabled(backgroundSyncEnabled) }
    }
    @Published var syncIntervalMinutes: Int {
        didSet { preferencesStore.setSyncIntervalMinutes(syncIntervalMinutes) }
    }
    @Published var offlinePDFCachingEnabled: Bool {
        didSet { preferencesStore.setOfflinePDFCachingEnabled(offlinePDFCachingEnabled) }
    }
    @Published var cacheRetentionDays: Int {
        didSet { preferencesStore.setCacheRetentionDays(cacheRetentionDays) }
    }
    @Published private var workspaceSyncNotices: [String: WorkspaceSyncNotice] = [:]
    @Published var localCacheSize = "0 KB"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let connectionStore: APIConnectionStore
    private let preferencesStore: AppPreferencesStore
    private var projectOverrides: [String: ProjectDetail] = [:]
    private var searchWorkspaces: [String: SearchWorkspace] = [:]
    private var workspaceSyncMetadata: [String: WorkspaceSyncMetadata] = [:]

    init(apiClient: APIClient, connectionStore: APIConnectionStore, preferencesStore: AppPreferencesStore) {
        self.apiClient = apiClient
        self.connectionStore = connectionStore
        self.preferencesStore = preferencesStore
        self.aiConnections = connectionStore.loadConnections()
        self.hasCompletedAISetup = connectionStore.isSetupComplete()
        self.appearancePreference = preferencesStore.loadAppearancePreference()
        self.useCompactProjectCards = preferencesStore.loadCompactProjectCards()
        self.syncOnLaunch = preferencesStore.loadSyncOnLaunch()
        self.backgroundSyncEnabled = preferencesStore.loadBackgroundSyncEnabled()
        self.syncIntervalMinutes = preferencesStore.loadSyncIntervalMinutes()
        self.offlinePDFCachingEnabled = preferencesStore.loadOfflinePDFCachingEnabled()
        self.cacheRetentionDays = preferencesStore.loadCacheRetentionDays()
        preferencesStore.ensureCacheDirectoryExists()
        self.localCacheSize = preferencesStore.formattedCacheSize()
    }

    convenience init() {
        self.init(
            apiClient: APIClient(),
            connectionStore: APIConnectionStore(),
            preferencesStore: AppPreferencesStore()
        )
    }

    var preferredColorScheme: ColorScheme? {
        switch appearancePreference {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await apiClient.login(email: email, password: password)
            currentUser = session.user
            projects = session.projects
            selectedProjectID = session.projects.first?.id
            isAuthenticated = true
            showPostLoginScreen = true
            isLoading = false

            if let projectID = selectedProjectID {
                await loadProjectDetail(projectID: projectID)
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refreshProjects() async {
        guard isAuthenticated else { return }
        isLoading = true
        errorMessage = nil

        do {
            let remoteProjects = try await apiClient.fetchProjects()
            projects = mergeProjects(remoteProjects)
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
            if let projectID = selectedProjectID {
                await loadProjectDetail(projectID: projectID)
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadProjectDetail(projectID: String) async {
        if let override = projectOverrides[projectID] {
            selectedProject = override
            selectedProjectID = projectID
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await apiClient.fetchProject(id: projectID)
            selectedProjectID = projectID
            await loadProjectWorkspace(projectID: projectID)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func signOut() {
        apiClient.clearSession()
        showHomeScreen = true
        showPostLoginScreen = false
        isAuthenticated = false
        currentUser = nil
        projects = []
        selectedProjectID = nil
        selectedProject = nil
        errorMessage = nil
        projectOverrides = [:]
        searchWorkspaces = [:]
    }

    func addAIConnection(
        provider: AIProvider,
        mode: AIConnectionMode,
        label: String,
        apiKey: String
    ) {
        let connection = AIConnection(
            id: UUID(),
            provider: provider,
            mode: mode,
            label: label.isEmpty ? provider.displayName : label,
            createdAt: Date()
        )

        aiConnections.append(connection)
        connectionStore.saveConnections(aiConnections)

        if mode == .ownAPIKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            connectionStore.saveAPIKey(apiKey, for: connection.id)
        }
    }

    func removeAIConnection(_ connection: AIConnection) {
        aiConnections.removeAll { $0.id == connection.id }
        connectionStore.saveConnections(aiConnections)
        connectionStore.removeAPIKey(for: connection.id)
    }

    func completeAISetup() {
        hasCompletedAISetup = true
        connectionStore.setSetupComplete(true)
    }

    func continueFromHomeScreen() {
        showHomeScreen = false
    }

    func continueToProjects() {
        showPostLoginScreen = false
    }

    func reopenAISetup() {
        hasCompletedAISetup = false
        connectionStore.setSetupComplete(false)
    }

    func hasStoredKey(for connection: AIConnection) -> Bool {
        connection.mode == .ownAPIKey ? connectionStore.hasAPIKey(for: connection.id) : false
    }

    func storedAPIKey(for connection: AIConnection) -> String? {
        guard connection.mode == .ownAPIKey else { return nil }
        return connectionStore.apiKey(for: connection.id)
    }

    func localCachePath() -> String {
        preferencesStore.cacheDirectoryURL().path
    }

    func refreshLocalCacheSize() {
        localCacheSize = preferencesStore.formattedCacheSize()
    }

    func clearLocalCache() {
        do {
            try preferencesStore.clearCache()
            refreshLocalCacheSize()
        } catch {
            errorMessage = "Could not clear the local cache: \(error.localizedDescription)"
        }
    }

    func workspaceSyncNotice(for projectID: String) -> WorkspaceSyncNotice? {
        workspaceSyncNotices[projectID]
    }

    func clearWorkspaceSyncNotice(for projectID: String) {
        workspaceSyncNotices.removeValue(forKey: projectID)
    }

    func reloadSharedWorkspace(projectID: String) async {
        await loadProjectWorkspace(projectID: projectID)
    }

    func resolveWorkspaceConflict(
        projectID: String,
        mergedWorkspace: SearchWorkspace,
        serverVersion: Int,
        serverUpdatedAt: Date,
        editorName: String?,
        syncNow: Bool = true
    ) {
        workspaceSyncMetadata[projectID] = WorkspaceSyncMetadata(
            version: serverVersion,
            updatedAt: serverUpdatedAt,
            updatedBy: nil,
            editorName: editorName
        )
        workspaceSyncNotices.removeValue(forKey: projectID)
        applySearchWorkspace(mergedWorkspace, for: projectID, shouldSync: syncNow)
    }

    func searchWorkspace(for project: ProjectDetail) -> SearchWorkspace {
        if let workspace = searchWorkspaces[project.id] {
            return workspace
        }
        return SearchWorkspace(project: project)
    }

    func saveSearchWorkspace(_ workspace: SearchWorkspace, for projectID: String) {
        applySearchWorkspace(workspace, for: projectID, shouldSync: true)
    }

    private func applySearchWorkspace(_ workspace: SearchWorkspace, for projectID: String, shouldSync: Bool) {
        searchWorkspaces[projectID] = workspace
        guard let current = resolvedProjectDetail(for: projectID) else { return }

        let updatedStage: ProjectStage
        if workspace.hasReportDraftActivity {
            updatedStage = .reporting
        } else if workspace.hasSynthesisActivity {
            updatedStage = .synthesis
        } else if workspace.hasExtractionActivity {
            updatedStage = .extraction
        } else if workspace.hasFullTextActivity {
            updatedStage = .full_text
        } else if workspace.hasScreeningActivity {
            updatedStage = .screening
        } else if current.stage == .setup {
            updatedStage = .search
        } else {
            updatedStage = current.stage
        }

        let updatedProgress: Double
        if workspace.hasReportDraftActivity {
            updatedProgress = max(current.progress, 0.92)
        } else if workspace.hasSynthesisActivity {
            updatedProgress = max(current.progress, 0.84)
        } else if workspace.hasExtractionActivity {
            updatedProgress = max(current.progress, 0.72)
        } else if workspace.hasFullTextActivity {
            updatedProgress = max(current.progress, 0.55)
        } else if workspace.hasScreeningActivity {
            updatedProgress = max(current.progress, 0.35)
        } else {
            updatedProgress = max(current.progress, workspace.importedReferences.isEmpty ? 0.12 : 0.2)
        }
        let updatedActions = nextActions(
            for: current,
            workspace: workspace
        )

        let updated = ProjectDetail(
            id: current.id,
            title: current.title,
            reviewQuestion: current.reviewQuestion,
            stage: updatedStage,
            health: current.health,
            progress: updatedProgress,
            referencesCount: workspace.importedReferences.count,
            collaboratorsCount: current.collaboratorsCount,
            updatedAt: Date(),
            teamName: current.teamName,
            description: current.description,
            population: current.population,
            intervention: current.intervention,
            comparator: current.comparator,
            outcome: current.outcome,
            studyDesign: current.studyDesign,
            humanReviewPolicy: current.humanReviewPolicy,
            aiAssistPolicy: current.aiAssistPolicy,
            lead: current.lead,
            members: current.members,
            automations: current.automations,
            nextActions: updatedActions
        )

        projectOverrides[projectID] = updated
        if let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index] = ProjectSummary(detail: updated)
        }
        if selectedProjectID == projectID {
            selectedProject = updated
        }

        if shouldSync && isAuthenticated {
            Task {
                await syncWorkspaceToServer(workspace, for: projectID, using: updated)
            }
        }
    }

    func createProject(from draft: ProjectDraft) {
        let now = Date()
        let lead = currentUser ?? UserSummary(
            id: "user_local",
            name: "Local Reviewer",
            email: "local@example.com",
            title: "Lead Reviewer"
        )

        var members = draft.members.map { member in
            MemberSummary(
                id: member.id,
                name: member.name,
                email: member.email.isEmpty ? nil : member.email,
                role: member.role,
                assignedStages: member.role == .owner ? ReviewProcessStage.allCases : member.assignedStages
            )
        }

        if !members.contains(where: { $0.id == lead.id }) {
            members.insert(
                MemberSummary(id: lead.id, name: lead.name, email: lead.email, role: .owner, assignedStages: ReviewProcessStage.allCases),
                at: 0
            )
        }

        let newID = "proj_local_\(UUID().uuidString.lowercased())"
        let detail = ProjectDetail(
            id: newID,
            title: draft.title,
            reviewQuestion: draft.reviewQuestion,
            stage: .setup,
            health: .onTrack,
            progress: 0.05,
            referencesCount: 0,
            collaboratorsCount: members.count,
            updatedAt: now,
            teamName: draft.teamName.isEmpty ? "New Review Team" : draft.teamName,
            description: draft.description,
            population: draft.population,
            intervention: draft.intervention,
            comparator: draft.comparator,
            outcome: draft.outcome,
            studyDesign: draft.studyDesign,
            humanReviewPolicy: draft.humanReviewPolicy,
            aiAssistPolicy: draft.aiAssistPolicy,
            lead: lead,
            members: members,
            automations: [],
            nextActions: [
                "Review the protocol and human decision rules",
                "Import references for the search stage",
                "Invite collaborators and assign review roles"
            ]
        )

        projectOverrides[newID] = detail
        projects.insert(ProjectSummary(detail: detail), at: 0)
        selectedProjectID = newID
        selectedProject = detail
    }

    func updateProject(projectID: String, from draft: ProjectDraft) {
        guard let current = resolvedProjectDetail(for: projectID) else { return }

        let lead = current.lead
        var members = draft.members.map { member in
            MemberSummary(
                id: member.id,
                name: member.name,
                email: member.email.isEmpty ? nil : member.email,
                role: member.role,
                assignedStages: member.role == .owner ? ReviewProcessStage.allCases : member.assignedStages
            )
        }

        if !members.contains(where: { $0.id == lead.id }) {
            members.insert(
                MemberSummary(id: lead.id, name: lead.name, email: lead.email, role: .owner, assignedStages: ReviewProcessStage.allCases),
                at: 0
            )
        }

        let updated = ProjectDetail(
            id: current.id,
            title: draft.title,
            reviewQuestion: draft.reviewQuestion,
            stage: current.stage,
            health: current.health,
            progress: current.progress,
            referencesCount: current.referencesCount,
            collaboratorsCount: members.count,
            updatedAt: Date(),
            teamName: draft.teamName.isEmpty ? current.teamName : draft.teamName,
            description: draft.description,
            population: draft.population,
            intervention: draft.intervention,
            comparator: draft.comparator,
            outcome: draft.outcome,
            studyDesign: draft.studyDesign,
            humanReviewPolicy: draft.humanReviewPolicy,
            aiAssistPolicy: draft.aiAssistPolicy,
            lead: lead,
            members: members,
            automations: current.automations,
            nextActions: current.nextActions
        )

        projectOverrides[projectID] = updated
        if let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index] = ProjectSummary(detail: updated)
        }
        if selectedProjectID == projectID {
            selectedProject = updated
        }

        if isAuthenticated && !projectID.hasPrefix("proj_local_") {
            Task {
                await syncProjectDetailToServer(projectID: projectID, draft: draft)
            }
        }
    }

    private func mergeProjects(_ remoteProjects: [ProjectSummary]) -> [ProjectSummary] {
        var merged = Dictionary(uniqueKeysWithValues: remoteProjects.map { ($0.id, $0) })
        for override in projectOverrides.values {
            merged[override.id] = ProjectSummary(detail: override)
        }
        return merged.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func resolvedProjectDetail(for projectID: String) -> ProjectDetail? {
        if let override = projectOverrides[projectID] {
            return override
        }
        if selectedProject?.id == projectID {
            return selectedProject
        }
        return nil
    }

    private func loadProjectWorkspace(projectID: String) async {
        do {
            if let remotePayload = try await apiClient.fetchProjectWorkspace(projectID: projectID) {
                searchWorkspaces[projectID] = remotePayload.workspace
                workspaceSyncMetadata[projectID] = remotePayload.metadata
                workspaceSyncNotices.removeValue(forKey: projectID)
                if let current = resolvedProjectDetail(for: projectID) {
                    applySearchWorkspace(remotePayload.workspace, for: current.id, shouldSync: false)
                }
            }
        } catch {
            // Keep local workspace state if no remote snapshot exists yet.
        }
    }

    private func syncWorkspaceToServer(_ workspace: SearchWorkspace, for projectID: String, using detail: ProjectDetail) async {
        do {
            let syncMetadata = try await apiClient.syncProjectWorkspace(
                projectID: projectID,
                workspace: workspace,
                stage: detail.stage,
                progress: detail.progress,
                referencesCount: detail.referencesCount,
                baseVersion: workspaceSyncMetadata[projectID]?.version,
                updatedBy: currentUser?.id ?? "local_user",
                editorName: currentUser?.name ?? "Local Reviewer"
            )
            workspaceSyncMetadata[projectID] = syncMetadata
            workspaceSyncNotices.removeValue(forKey: projectID)
        } catch let APIClientError.workspaceConflict(conflict) {
            let serverWorkspace = (try? apiClient.decodeWorkspaceEnvelope(conflict.latestSnapshot)) ?? workspace
            workspaceSyncNotices[projectID] = WorkspaceSyncNotice(
                projectID: projectID,
                message: conflict.message,
                serverVersion: conflict.latestSnapshot.version,
                serverUpdatedAt: conflict.latestSnapshot.updatedAt,
                editorName: conflict.latestSnapshot.editorName,
                localWorkspace: workspace,
                serverWorkspace: serverWorkspace
            )
            errorMessage = conflict.message
        } catch {
            // Local-first behavior remains intact if backend sync is unavailable.
        }
    }

    private func syncProjectDetailToServer(projectID: String, draft: ProjectDraft) async {
        do {
            let remoteDetail = try await apiClient.updateProject(id: projectID, draft: draft)
            projectOverrides[projectID] = remoteDetail
            if let index = projects.firstIndex(where: { $0.id == projectID }) {
                projects[index] = ProjectSummary(detail: remoteDetail)
            }
            if selectedProjectID == projectID {
                selectedProject = remoteDetail
            }
        } catch {
            errorMessage = "Saved locally, but could not update collaborators on the server: \(error.localizedDescription)"
        }
    }

    private func nextActions(for project: ProjectDetail, workspace: SearchWorkspace) -> [String] {
        if workspace.hasReportDraftActivity {
            return [
                workspace.reportSectionCompletionCount >= 9 ? "All core report sections now have draft content" : "Continue drafting the remaining report sections",
                "Review AI-assisted wording against the extracted evidence before export",
                "Export and circulate the report only after a human final review"
            ]
        }

        if workspace.hasSynthesisActivity {
            return [
                workspace.synthesizedFieldCount >= max(1, workspace.allFlatFields.count / 2) ? "Synthesis drafting is underway across the extracted variables" : "Draft synthesis notes for the key extracted variables",
                "Carry only reviewer-checked interpretations into the report stage",
                "Start report writing once the main variable syntheses are complete"
            ]
        }

        if workspace.hasExtractionActivity {
            let counts = workspace.extractionCompletionCounts
            return [
                counts.completed == counts.eligible ? "All included studies now have extracted data recorded" : "Complete extraction for \(counts.eligible - counts.completed) included study/studies",
                counts.qaStarted == counts.eligible ? "Quality appraisal has been recorded for all included studies" : "Record QA judgments for \(counts.eligible - counts.qaStarted) included study/studies",
                "Keep extracted values and evidence excerpts reviewer-authored, with AI used only for drafting support"
            ]
        }

        if workspace.hasFullTextActivity {
            let counts = workspace.fullTextCounts
            let retrieval = workspace.fullTextRetrievalCounts
            return [
                retrieval.missing == 0 ? "All eligible studies have PDFs attached or retrieved" : "Attach or retrieve \(retrieval.missing) missing PDF(s)",
                counts.conflicts == 0 ? "Review included full-text studies before extraction" : "Resolve \(counts.conflicts) full-text conflict(s) with a human reviewer",
                "Keep final full-text inclusion decisions under human control"
            ]
        }

        if workspace.hasScreeningActivity {
            let counts = workspace.screeningCounts
            return [
                counts.conflicts == 0 ? "Review included studies and confirm they should proceed to full text" : "Resolve \(counts.conflicts) screening conflict(s) with a human reviewer",
                "Audit AI suggestions before treating any screening decision as final",
                "Document reasons for exclusion where needed"
            ]
        }

        if workspace.importedReferences.isEmpty {
            return [
                "Finalize the human-approved search strategy",
                "Document databases and exact search strings",
                "Import references before starting screening"
            ]
        }

        return [
            "Review imported references for duplicates and search coverage",
            "Confirm the search strategy before title and abstract screening",
            "Invite reviewers and assign screening roles"
        ]
    }
}
