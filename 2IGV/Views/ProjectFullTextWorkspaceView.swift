import SwiftUI
import UniformTypeIdentifiers

private enum FullTextWorkspaceTab: String, CaseIterable, Identifiable {
    case retrieval = "Retrieval"
    case screening = "Screening"
    case results = "Results"
    case conflicts = "Conflicts"

    var id: String { rawValue }
}

private enum FullTextResultsFilter: String, CaseIterable, Identifiable {
    case included = "Included"
    case excluded = "Excluded"
    case pending = "Pending"

    var id: String { rawValue }
}

struct ProjectFullTextWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail
    let allowedStages: Set<ReviewProcessStage>

    @State private var workspace = SearchWorkspace()
    @State private var activeTab: FullTextWorkspaceTab
    @State private var selectedReferenceID: String?
    @State private var uploadTargetID: String?
    @State private var isImporterPresented = false
    @State private var isRetrieving = false
    @State private var isGeneratingSuggestions = false
    @State private var resultsFilter: FullTextResultsFilter = .included
    @State private var statusMessage = ""

    private let documentStore = FullTextDocumentStore()

    init(
        project: ProjectDetail,
        allowedStages: Set<ReviewProcessStage> = [.fullTextRetrieval, .fullTextScreening]
    ) {
        self.project = project
        self.allowedStages = allowedStages
        self._activeTab = State(initialValue: allowedStages.contains(.fullTextRetrieval) ? .retrieval : .screening)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Full Text", selection: $activeTab) {
                ForEach(availableTabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            switch activeTab {
            case .retrieval:
                retrievalView
            case .screening:
                screeningView
            case .results:
                resultsView
            case .conflicts:
                conflictsView
            }

            footer
        }
        .frame(minWidth: 1180, minHeight: 800)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            workspace = appState.searchWorkspace(for: project)
            if !availableTabs.contains(activeTab) {
                activeTab = availableTabs.first ?? .retrieval
            }
            autoSelectReference()
        }
        .onDisappear {
            persistWorkspace()
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.pdf]) { result in
            handlePDFImport(result)
        }
    }

    private var canUseRetrieval: Bool {
        allowedStages.contains(.fullTextRetrieval)
    }

    private var canUseScreening: Bool {
        allowedStages.contains(.fullTextScreening)
    }

    private var availableTabs: [FullTextWorkspaceTab] {
        var tabs: [FullTextWorkspaceTab] = []
        if canUseRetrieval {
            tabs.append(.retrieval)
        }
        if canUseScreening {
            tabs.append(contentsOf: [.screening, .results, .conflicts])
        }
        return tabs
    }

    private var header: some View {
        let retrieval = workspace.fullTextRetrievalCounts
        let counts = workspace.fullTextCounts

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("3-4. Full Text Review")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(project.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Text("Humans stay in charge here too. AI can help surface likely include or exclude signals, but reviewers should confirm the correct PDF is attached and make the final full-text decision.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusBadge(text: "\(retrieval.attached) PDFs attached", tint: .blue)
                StatusBadge(text: "\(counts.included) Included", tint: .green)
                StatusBadge(text: "\(counts.excluded) Excluded", tint: .red)
                StatusBadge(text: "\(counts.conflicts) Conflicts", tint: .orange)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.89, blue: 0.84), Color(red: 0.84, green: 0.90, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var retrievalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if eligibleFullTextReferences.isEmpty {
                    ContentUnavailableView(
                        "No Studies Ready",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Only records included at title and abstract stage move into full-text retrieval.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    retrievalSummaryCard
                    retrievalListCard
                }
            }
            .padding(24)
        }
    }

    private var retrievalSummaryCard: some View {
        let retrieval = workspace.fullTextRetrievalCounts

        return HStack(spacing: 16) {
            FullTextMetricCard(title: "Eligible", value: "\(retrieval.eligible)", subtitle: "records from TAS")
            FullTextMetricCard(title: "Attached", value: "\(retrieval.attached)", subtitle: "PDFs ready for review")
            FullTextMetricCard(title: "Missing", value: "\(retrieval.missing)", subtitle: "still need retrieval")
        }
    }

    private var retrievalListCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PDF Retrieval")
                    .font(.title3.weight(.semibold))
                Spacer()
                if isRetrieving {
                    ProgressView("Retrieving...")
                } else {
                    Button("Auto-Retrieve") {
                        startAutoRetrieval()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canUseRetrieval)
                }
            }

            Text("Check each attachment before screening. A correct PDF matters more than a fast PDF.")
                .foregroundStyle(.secondary)

            ForEach(eligibleFullTextReferences) { reference in
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                            .font(.headline)
                        Text(reference.formattedAuthors)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if reference.retrievalStatus != .none {
                            StatusBadge(text: reference.retrievalStatus.rawValue, tint: retrievalTint(for: reference.retrievalStatus))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Button(reference.pdfURL == nil ? "Attach PDF" : "Replace PDF") {
                            uploadTargetID = reference.id
                            isImporterPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canUseRetrieval)

                        if reference.pdfURL != nil, canUseScreening {
                            Button("Open in Screening") {
                                selectedReferenceID = reference.id
                                activeTab = .screening
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
            }
        }
    }

    private var screeningView: some View {
        Group {
            if eligibleFullTextReferences.isEmpty {
                ContentUnavailableView(
                    "No Full-Text Queue",
                    systemImage: "doc.viewfinder",
                    description: Text("Include studies at title and abstract stage before entering full-text review.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        screeningSidebar
                            .frame(width: geo.size.width * 0.22)
                        Divider()
                        screeningDetail
                            .frame(width: geo.size.width * 0.78)
                    }
                }
            }
        }
    }

    private var screeningSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Full-Text Queue")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(isGeneratingSuggestions ? "Generating..." : "Suggest All AI") {
                    generateSuggestionsForAllFullText()
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingSuggestions)
            }
            .padding(20)

            List(selection: Binding(
                get: { selectedReferenceID },
                set: { selectedReferenceID = $0 }
            )) {
                ForEach(eligibleFullTextReferences) { reference in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(tint(for: reference.fullTextConsensusStatus))
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                                .lineLimit(2)
                            Text(reference.customID.isEmpty ? "No ID" : "Ref \(reference.customID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(reference.id)
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var screeningDetail: some View {
        Group {
            if let reference = selectedFullTextReference {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        pdfPanel(for: reference)
                            .frame(width: geo.size.width * 0.58)
                        Divider()
                        decisionPanel(for: reference)
                            .frame(width: geo.size.width * 0.42)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Study",
                    systemImage: "doc.text",
                    description: Text("Choose a study from the queue to review the PDF, AI suggestions, and full-text decision controls.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pdfPanel(for reference: ImportedReference) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PDF Review")
                    .font(.title3.weight(.semibold))
                Spacer()
                if reference.pdfURL == nil {
                    Button("Attach PDF") {
                        uploadTargetID = reference.id
                        isImporterPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if let pdfURL = reference.pdfURL {
                PDFPreviewView(url: pdfURL)
                    .padding(20)
            } else {
                ContentUnavailableView(
                    "No PDF Attached",
                    systemImage: "doc.viewfinder",
                    description: Text("Attach a PDF or try auto-retrieval before making a full-text decision.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func decisionPanel(for reference: ImportedReference) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                        .font(.headline)
                    Text(reference.cleanAbstract.isEmpty ? "No abstract imported." : reference.cleanAbstract)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("AI Suggestions")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button(isGeneratingSuggestions ? "Generating..." : (reference.fullTextAIVotes.isEmpty ? "Generate Suggestions" : "Refresh Suggestions")) {
                            generateFullTextSuggestions(for: reference.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGeneratingSuggestions)
                    }

                    Text("These suggestions should never outrank reviewer judgment. Use them as prompts, not conclusions.")
                        .foregroundStyle(.secondary)

                    if reference.fullTextAIVotes.isEmpty {
                        Text("No AI suggestions generated yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(reference.fullTextAIVotes) { vote in
                            FullTextVoteRow(vote: vote)
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Human Decision")
                        .font(.title3.weight(.semibold))
                    Text("A reviewer should make the final decision here after checking the PDF and protocol.")
                        .foregroundStyle(.secondary)

                    if let humanVote = reference.fullTextHumanVotes.last {
                        FullTextVoteRow(vote: humanVote)
                    } else {
                        Text("No human full-text decision recorded yet.")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        fullTextDecisionButton("Include", decision: .included, referenceID: reference.id)
                        fullTextDecisionButton("Exclude", decision: .excluded, referenceID: reference.id)
                        fullTextDecisionButton("Need Info", decision: .insufficientInfo, referenceID: reference.id)
                    }

                    if reference.hasFullTextConflict {
                        Text("This record has conflicting full-text signals and requires explicit human resolution.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
                .background(cardBackground)
            }
            .padding(20)
        }
    }

    private var resultsView: some View {
        let counts = workspace.fullTextCounts

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    FullTextMetricCard(title: "Included", value: "\(counts.included)", subtitle: "move toward extraction")
                    FullTextMetricCard(title: "Excluded", value: "\(counts.excluded)", subtitle: "stopped at full text")
                    FullTextMetricCard(title: "Pending", value: "\(counts.pending)", subtitle: "need full-text review")
                }

                VStack(alignment: .leading, spacing: 16) {
                    Picker("Results", selection: $resultsFilter) {
                        ForEach(FullTextResultsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredFullTextResults.isEmpty {
                        ContentUnavailableView(
                            "No Records",
                            systemImage: "tray",
                            description: Text("There are no full-text records in this result bucket yet.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredFullTextResults) { reference in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                                        .font(.headline)
                                    Spacer()
                                    StatusBadge(text: reference.fullTextConsensusStatus.rawValue, tint: tint(for: reference.fullTextConsensusStatus))
                                }
                                Text(reference.formattedAuthors)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(cardBackground)
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)
            }
            .padding(24)
        }
    }

    private var conflictsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if fullTextConflicts.isEmpty {
                    ContentUnavailableView(
                        "No Full-Text Conflicts",
                        systemImage: "checkmark.shield",
                        description: Text("Any disagreement between AI signals and reviewer decisions will surface here until a person resolves it.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(fullTextConflicts) { reference in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                                .font(.headline)
                            Text(reference.cleanAbstract.isEmpty ? "No abstract imported." : reference.cleanAbstract)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)

                            if !reference.fullTextAIVotes.isEmpty {
                                ForEach(reference.fullTextAIVotes) { vote in
                                    FullTextVoteRow(vote: vote)
                                }
                            }

                            HStack(spacing: 12) {
                                Button("Resolve as Include") {
                                    applyFullTextDecision(.included, to: reference.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)

                                Button("Resolve as Exclude") {
                                    applyFullTextDecision(.excluded, to: reference.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                    }
                }
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            Text("Keep a human in the loop for every attached PDF and every final full-text decision.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save & Close") {
                persistWorkspace()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private var eligibleFullTextReferences: [ImportedReference] {
        workspace.importedReferences.filter(\.isEligibleForFullText)
    }

    private var selectedFullTextReference: ImportedReference? {
        guard let selectedReferenceID else { return nil }
        return eligibleFullTextReferences.first { $0.id == selectedReferenceID }
    }

    private var filteredFullTextResults: [ImportedReference] {
        switch resultsFilter {
        case .included:
            return eligibleFullTextReferences.filter { $0.fullTextConsensusStatus == .included }
        case .excluded:
            return eligibleFullTextReferences.filter { $0.fullTextConsensusStatus == .excluded }
        case .pending:
            return eligibleFullTextReferences.filter { $0.fullTextConsensusStatus == .unknown || $0.fullTextConsensusStatus == .insufficientInfo }
        }
    }

    private var fullTextConflicts: [ImportedReference] {
        eligibleFullTextReferences.filter(\.hasFullTextConflict)
    }

    private func autoSelectReference() {
        if selectedReferenceID == nil || !eligibleFullTextReferences.contains(where: { $0.id == selectedReferenceID }) {
            selectedReferenceID = eligibleFullTextReferences.first?.id
        }
    }

    private func handlePDFImport(_ result: Result<URL, Error>) {
        guard canUseRetrieval else {
            statusMessage = "You are not assigned to full-text retrieval in this project."
            return
        }

        do {
            let sourceURL = try result.get()
            guard let uploadTargetID else { return }
            guard sourceURL.startAccessingSecurityScopedResource() else {
                statusMessage = "The selected PDF could not be opened."
                return
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let storedURL = try documentStore.importPDF(from: sourceURL, referenceID: uploadTargetID)
            updateReference(uploadTargetID) { reference in
                reference.pdfLocalPath = storedURL.path
                reference.retrievalStatus = .found
            }
            statusMessage = "PDF attached."
            activeTab = canUseScreening ? .screening : .retrieval
        } catch {
            statusMessage = "PDF import failed: \(error.localizedDescription)"
        }
    }

    private func startAutoRetrieval() {
        guard canUseRetrieval else {
            statusMessage = "You are not assigned to full-text retrieval in this project."
            return
        }

        isRetrieving = true
        statusMessage = "Attempting open-access retrieval for eligible studies..."

        Task {
            let idsToRetrieve = eligibleFullTextReferences
                .filter { $0.pdfURL == nil }
                .map(\.id)

            for referenceID in idsToRetrieve {
                updateReference(referenceID) { reference in
                    reference.retrievalStatus = .searching
                }

                guard let reference = workspace.importedReferences.first(where: { $0.id == referenceID }) else {
                    continue
                }

                let result = await PDFRetrievalService.attemptRetrieval(for: reference)
                updateReference(referenceID) { mutableReference in
                    if result.success, let localURL = result.localURL {
                        mutableReference.pdfLocalPath = localURL.path
                        mutableReference.retrievalStatus = .found
                    } else {
                        mutableReference.retrievalStatus = result.status
                    }
                }
            }

            await MainActor.run {
                isRetrieving = false
                statusMessage = "Full-text retrieval pass completed."
                persistWorkspace()
            }
        }
    }

    private func generateSuggestionsForAllFullText() {
        guard canUseScreening else {
            statusMessage = "You are not assigned to full-text screening in this project."
            return
        }

        let ids = eligibleFullTextReferences.map(\.id)
        isGeneratingSuggestions = true
        statusMessage = "Generating AI suggestions for full-text review..."

        Task {
            for id in ids {
                await performGenerateFullTextSuggestions(for: id)
            }

            await MainActor.run {
                isGeneratingSuggestions = false
                statusMessage = "Full-text suggestions updated."
                persistWorkspace()
            }
        }
    }

    private func generateFullTextSuggestions(for referenceID: String) {
        guard canUseScreening else {
            statusMessage = "You are not assigned to full-text screening in this project."
            return
        }

        Task {
            await performGenerateFullTextSuggestions(for: referenceID)
        }
    }

    private func performGenerateFullTextSuggestions(for referenceID: String) async {
        guard let index = workspace.importedReferences.firstIndex(where: { $0.id == referenceID }) else { return }

        let suggestions = await FullTextSuggestionService.generateSuggestions(
            for: workspace.importedReferences[index],
            connections: appState.aiConnections,
            apiKeyLookup: { connection in
                appState.storedAPIKey(for: connection)
            }
        )
        await MainActor.run {
            let humanVotes = workspace.importedReferences[index].fullTextHumanVotes
            workspace.importedReferences[index].fullTextVotes = humanVotes + suggestions
            statusMessage = suggestions.isEmpty
                ? "No live AI suggestions were returned, so the local full-text fallback stayed in place."
                : "Full-text suggestions updated for \(workspace.importedReferences[index].title.isEmpty ? "the selected study" : workspace.importedReferences[index].title)."
            persistWorkspace()
        }
    }

    private func applyFullTextDecision(_ decision: ScreeningDecision, to referenceID: String) {
        guard canUseScreening else {
            statusMessage = "You are not assigned to full-text screening in this project."
            return
        }

        let reviewerName = appState.currentUser?.name ?? "Human Reviewer"
        let humanVote = ScreeningVote(
            screenerName: reviewerName,
            decision: decision,
            reason: fullTextReason(for: decision),
            criterionUsed: fullTextCriterion(for: decision),
            isAI: false
        )

        updateReference(referenceID) { reference in
            let aiVotes = reference.fullTextAIVotes
            reference.fullTextVotes = aiVotes + [humanVote]
            reference.fullTextFinalDecision = decision
            reference.fullTextReason = humanVote.reason
        }
    }

    private func updateReference(_ referenceID: String, mutate: (inout ImportedReference) -> Void) {
        guard let index = workspace.importedReferences.firstIndex(where: { $0.id == referenceID }) else { return }
        mutate(&workspace.importedReferences[index])
        persistWorkspace()
        autoSelectReference()
    }

    private func fullTextCriterion(for decision: ScreeningDecision) -> String {
        switch decision {
        case .included:
            return "Meets full-text inclusion requirements"
        case .excluded:
            return "Fails full-text eligibility requirements"
        case .insufficientInfo:
            return "More full-text review needed"
        case .conflict, .unknown:
            return "Manual review"
        }
    }

    private func fullTextReason(for decision: ScreeningDecision) -> String {
        switch decision {
        case .included:
            return "Human reviewer confirmed the study should proceed after full-text review."
        case .excluded:
            return "Human reviewer excluded the study after checking the full text."
        case .insufficientInfo:
            return "Human reviewer needs more information before deciding on the full text."
        case .conflict, .unknown:
            return "Human reviewer left the record unresolved."
        }
    }

    private func persistWorkspace() {
        appState.saveSearchWorkspace(workspace, for: project.id)
    }

    private func tint(for decision: ScreeningDecision) -> Color {
        switch decision {
        case .included:
            return .green
        case .excluded:
            return .red
        case .conflict:
            return .orange
        case .insufficientInfo:
            return .yellow
        case .unknown:
            return .gray
        }
    }

    private func retrievalTint(for status: RetrievalStatus) -> Color {
        switch status {
        case .none:
            return .gray
        case .searching:
            return .blue
        case .found:
            return .green
        case .notFound:
            return .orange
        case .error:
            return .red
        }
    }

    private func fullTextDecisionButton(_ label: String, decision: ScreeningDecision, referenceID: String) -> some View {
        Button(label) {
            applyFullTextDecision(decision, to: referenceID)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint(for: decision))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FullTextVoteRow: View {
    let vote: ScreeningVote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: vote.isAI ? "cpu" : "person.fill")
                .foregroundStyle(vote.isAI ? .blue : .brown)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vote.screenerName)
                        .font(.headline)
                    StatusBadge(text: vote.decision.rawValue, tint: tint(for: vote.decision))
                }
                Text("Criterion: \(vote.criterionUsed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vote.reason)
                    .font(.callout)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func tint(for decision: ScreeningDecision) -> Color {
        switch decision {
        case .included:
            return .green
        case .excluded:
            return .red
        case .conflict:
            return .orange
        case .insufficientInfo:
            return .yellow
        case .unknown:
            return .gray
        }
    }
}

private struct FullTextMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
