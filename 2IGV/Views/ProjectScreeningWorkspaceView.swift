import SwiftUI

private enum ScreeningWorkspaceTab: String, CaseIterable, Identifiable {
    case queue = "Queue"
    case results = "Results"
    case conflicts = "Conflicts"
    case criteria = "Criteria"

    var id: String { rawValue }
}

private enum ScreeningResultsFilter: String, CaseIterable, Identifiable {
    case included = "Included"
    case excluded = "Excluded"
    case pending = "Pending"

    var id: String { rawValue }
}

struct ProjectScreeningWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail

    @State private var workspace = SearchWorkspace()
    @State private var activeTab: ScreeningWorkspaceTab = .queue
    @State private var resultsFilter: ScreeningResultsFilter = .included
    @State private var selectedReferenceID: String?
    @State private var newInclusionName = ""
    @State private var newInclusionDescription = ""
    @State private var newExclusionName = ""
    @State private var newExclusionDescription = ""
    @State private var isGeneratingSuggestions = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Screening", selection: $activeTab) {
                ForEach(ScreeningWorkspaceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            switch activeTab {
            case .queue:
                queueView
            case .results:
                resultsView
            case .conflicts:
                conflictsView
            case .criteria:
                criteriaView
            }

            footer
        }
        .frame(minWidth: 1120, minHeight: 780)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            workspace = appState.searchWorkspace(for: project)
            autoSelectReference()
        }
        .onDisappear {
            persistWorkspace()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("2. Title & Abstract Screening")
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

            Text("AI suggestions can speed up triage, but this stage remains reviewer-led. Humans should verify every include, exclude, and conflict before records move forward.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusBadge(text: "\(workspace.screeningCounts.pending) Pending", tint: .gray)
                StatusBadge(text: "\(workspace.screeningCounts.included) Included", tint: .green)
                StatusBadge(text: "\(workspace.screeningCounts.excluded) Excluded", tint: .red)
                StatusBadge(text: "\(workspace.screeningCounts.conflicts) Conflicts", tint: .orange)
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
                colors: [Color(red: 0.95, green: 0.90, blue: 0.83), Color(red: 0.86, green: 0.92, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var queueView: some View {
        Group {
            if workspace.importedReferences.isEmpty {
                ContentUnavailableView(
                    "No References Ready",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Import references in the Search & Import stage before starting title and abstract screening.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        queueSidebar
                            .frame(width: geo.size.width * 0.28)
                        Divider()
                        queueDetail
                            .frame(width: geo.size.width * 0.72)
                    }
                }
            }
        }
    }

    private var queueSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review Queue")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(isGeneratingSuggestions ? "Generating..." : "Suggest All AI") {
                    generateSuggestionsForPendingReferences()
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingSuggestions)
            }
            .padding(20)

            List(selection: Binding(
                get: { selectedReferenceID },
                set: { selectedReferenceID = $0 }
            )) {
                ForEach(workspace.importedReferences) { reference in
                    ScreeningQueueRow(reference: reference)
                        .tag(reference.id)
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var queueDetail: some View {
        Group {
            if let reference = selectedReference {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailSummaryCard(reference: reference)
                        aiSuggestionsCard(reference: reference)
                        humanDecisionCard(reference: reference)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Select a Reference",
                    systemImage: "text.magnifyingglass",
                    description: Text("Choose a title from the queue to review the abstract, AI suggestions, and human decision controls.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func detailSummaryCard(reference: ImportedReference) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                        .font(.title3.weight(.semibold))
                    Text(reference.formattedAuthors)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: reference.consensusStatus.rawValue,
                    tint: tint(for: reference.consensusStatus)
                )
            }

            HStack(spacing: 16) {
                metadataLabel("Ref ID", reference.customID.isEmpty ? "Unnumbered" : reference.customID)
                metadataLabel("Year", reference.displayDate)
                if !reference.doi.isEmpty {
                    metadataLabel("DOI", reference.doi)
                }
            }

            Divider()

            Text("Abstract")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(highlight(reference.cleanAbstract.isEmpty ? "No abstract was imported for this reference." : reference.cleanAbstract))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(cardBackground)
    }

    private func aiSuggestionsCard(reference: ImportedReference) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AI Suggestions")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(isGeneratingSuggestions ? "Generating..." : (reference.aiVotes.isEmpty ? "Generate Suggestions" : "Refresh Suggestions")) {
                    generateSuggestions(for: reference.id)
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingSuggestions)
            }

            Text("These are suggestions only. They do not replace reviewer judgment and should be checked against the protocol and criteria.")
                .foregroundStyle(.secondary)

            if reference.aiVotes.isEmpty {
                Text("No AI suggestions generated yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reference.aiVotes) { vote in
                    ScreeningVoteRow(vote: vote)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func humanDecisionCard(reference: ImportedReference) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Human Decision")
                .font(.title3.weight(.semibold))

            Text("Record the reviewer decision here. This is the authoritative decision that determines whether the record moves forward.")
                .foregroundStyle(.secondary)

            if let humanVote = reference.humanVotes.last {
                ScreeningVoteRow(vote: humanVote)
            } else {
                Text("No human decision recorded yet.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                decisionButton("Include", decision: .included)
                decisionButton("Exclude", decision: .excluded)
                decisionButton("Need Info", decision: .insufficientInfo)
            }

            if reference.hasConflict {
                Text("This record has conflicting signals and should be resolved by a human reviewer.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ScreeningMetricCard(title: "Included", value: "\(workspace.screeningCounts.included)", subtitle: "ready for full text")
                    ScreeningMetricCard(title: "Excluded", value: "\(workspace.screeningCounts.excluded)", subtitle: "kept out by reviewers")
                    ScreeningMetricCard(title: "Pending", value: "\(workspace.screeningCounts.pending)", subtitle: "still need review")
                }

                VStack(alignment: .leading, spacing: 16) {
                    Picker("Results", selection: $resultsFilter) {
                        ForEach(ScreeningResultsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredResults.isEmpty {
                        ContentUnavailableView(
                            "No Records",
                            systemImage: "tray",
                            description: Text("There are no records in this result bucket yet.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(filteredResults) { reference in
                            ResultReferenceRow(reference: reference)
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
                if conflictReferences.isEmpty {
                    ContentUnavailableView(
                        "No Conflicts",
                        systemImage: "checkmark.shield",
                        description: Text("When AI suggestions and reviewer decisions disagree, they will appear here for explicit human resolution.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(conflictReferences) { reference in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                                .font(.headline)
                            Text(reference.cleanAbstract.isEmpty ? "No abstract imported." : reference.cleanAbstract)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)

                            if !reference.aiVotes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI suggestions")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    ForEach(reference.aiVotes) { vote in
                                        ScreeningVoteRow(vote: vote)
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                Button("Resolve as Include") {
                                    applyHumanDecision(.included, to: reference.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)

                                Button("Resolve as Exclude") {
                                    applyHumanDecision(.excluded, to: reference.id)
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

    private var criteriaView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Screening setup")
                        .font(.title3.weight(.semibold))

                    Picker("Mode", selection: $workspace.screeningMode) {
                        ForEach(ScreeningMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Text("Use this to reflect how humans and AI should participate. Even in AI-assisted triage, final decisions should still be audited by a person.")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(cardBackground)

                criteriaSection(
                    title: "Inclusion criteria",
                    criteria: workspace.inclusionCriteria,
                    newName: $newInclusionName,
                    newDescription: $newInclusionDescription,
                    onAdd: addInclusionCriterion,
                    onDelete: deleteInclusionCriterion
                )

                criteriaSection(
                    title: "Exclusion criteria",
                    criteria: workspace.exclusionCriteria,
                    newName: $newExclusionName,
                    newDescription: $newExclusionDescription,
                    onAdd: addExclusionCriterion,
                    onDelete: deleteExclusionCriterion
                )
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            Text("Screening decisions stay local to the project for now. Human reviewer decisions remain the authoritative outcome.")
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

    private var selectedReference: ImportedReference? {
        guard let selectedReferenceID else { return nil }
        return workspace.importedReferences.first { $0.id == selectedReferenceID }
    }

    private var filteredResults: [ImportedReference] {
        switch resultsFilter {
        case .included:
            return workspace.importedReferences.filter { $0.consensusStatus == .included }
        case .excluded:
            return workspace.importedReferences.filter { $0.consensusStatus == .excluded }
        case .pending:
            return workspace.importedReferences.filter { $0.consensusStatus == .unknown || $0.consensusStatus == .insufficientInfo }
        }
    }

    private var conflictReferences: [ImportedReference] {
        workspace.importedReferences.filter(\.hasConflict)
    }

    private func metadataLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }

    private func decisionButton(_ label: String, decision: ScreeningDecision) -> some View {
        Button(label) {
            guard let selectedReferenceID else { return }
            applyHumanDecision(decision, to: selectedReferenceID)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint(for: decision))
    }

    private func criteriaSection(
        title: String,
        criteria: [ScreeningCriterion],
        newName: Binding<String>,
        newDescription: Binding<String>,
        onAdd: @escaping () -> Void,
        onDelete: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            ForEach(criteria) { criterion in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(criterion.name)
                            .font(.headline)
                        Text(criterion.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        onDelete(criterion.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                Divider()
            }

            TextField("Criterion name", text: newName)
                .textFieldStyle(.roundedBorder)
            TextField("Criterion description", text: newDescription)
                .textFieldStyle(.roundedBorder)
            Button("Add Criterion", action: onAdd)
                .buttonStyle(.borderedProminent)
                .disabled(newName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(cardBackground)
    }

    private func autoSelectReference() {
        if selectedReferenceID == nil {
            selectedReferenceID = workspace.importedReferences.first?.id
        }
    }

    private func generateSuggestionsForPendingReferences() {
        let referenceIDs = workspace.importedReferences.map(\.id)
        isGeneratingSuggestions = true
        statusMessage = "Generating AI suggestions for the screening queue..."

        Task {
            for referenceID in referenceIDs {
                await performGenerateSuggestions(for: referenceID)
            }

            await MainActor.run {
                isGeneratingSuggestions = false
                statusMessage = "Screening suggestions updated."
                persistWorkspace()
            }
        }
    }

    private func generateSuggestions(for referenceID: String) {
        Task {
            await performGenerateSuggestions(for: referenceID)
        }
    }

    private func performGenerateSuggestions(for referenceID: String) async {
        guard let index = workspace.importedReferences.firstIndex(where: { $0.id == referenceID }) else { return }

        let suggestions = await ScreeningSuggestionService.generateSuggestions(
            for: workspace.importedReferences[index],
            inclusionCriteria: workspace.inclusionCriteria,
            exclusionCriteria: workspace.exclusionCriteria,
            connections: appState.aiConnections,
            apiKeyLookup: { connection in
                appState.storedAPIKey(for: connection)
            }
        )

        await MainActor.run {
            let humanVotes = workspace.importedReferences[index].humanVotes
            workspace.importedReferences[index].votes = humanVotes + suggestions
            statusMessage = suggestions.isEmpty
                ? "No live AI suggestions were returned, so the local fallback stayed in place."
                : "AI suggestions updated for \(workspace.importedReferences[index].title.isEmpty ? "the selected record" : workspace.importedReferences[index].title)."
            persistWorkspace()
        }
    }

    private func applyHumanDecision(_ decision: ScreeningDecision, to referenceID: String) {
        guard let index = workspace.importedReferences.firstIndex(where: { $0.id == referenceID }) else { return }

        let reviewerName = appState.currentUser?.name ?? "Human Reviewer"
        let criterion = criterionLabel(for: decision)
        let humanVote = ScreeningVote(
            screenerName: reviewerName,
            decision: decision,
            reason: humanReason(for: decision),
            criterionUsed: criterion,
            isAI: false
        )

        let aiVotes = workspace.importedReferences[index].aiVotes
        workspace.importedReferences[index].votes = aiVotes + [humanVote]
        workspace.importedReferences[index].finalDecision = decision
        persistWorkspace()
    }

    private func addInclusionCriterion() {
        workspace.inclusionCriteria.append(
            ScreeningCriterion(
                name: newInclusionName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: newInclusionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        newInclusionName = ""
        newInclusionDescription = ""
        persistWorkspace()
    }

    private func addExclusionCriterion() {
        workspace.exclusionCriteria.append(
            ScreeningCriterion(
                name: newExclusionName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: newExclusionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        newExclusionName = ""
        newExclusionDescription = ""
        persistWorkspace()
    }

    private func deleteInclusionCriterion(_ criterionID: String) {
        workspace.inclusionCriteria.removeAll { $0.id == criterionID }
        persistWorkspace()
    }

    private func deleteExclusionCriterion(_ criterionID: String) {
        workspace.exclusionCriteria.removeAll { $0.id == criterionID }
        persistWorkspace()
    }

    private func criterionLabel(for decision: ScreeningDecision) -> String {
        switch decision {
        case .included:
            return workspace.inclusionCriteria.first?.name ?? "Manual inclusion"
        case .excluded:
            return workspace.exclusionCriteria.first?.name ?? "Manual exclusion"
        case .insufficientInfo:
            return "Needs more information"
        case .conflict, .unknown:
            return "Manual review"
        }
    }

    private func humanReason(for decision: ScreeningDecision) -> String {
        switch decision {
        case .included:
            return "Human reviewer marked this record for full-text consideration."
        case .excluded:
            return "Human reviewer excluded this record at title and abstract stage."
        case .insufficientInfo:
            return "Human reviewer needs more information before deciding."
        case .conflict, .unknown:
            return "Human reviewer left the record unresolved."
        }
    }

    private func persistWorkspace() {
        appState.saveSearchWorkspace(workspace, for: project.id)
    }

    private func highlight(_ content: String) -> AttributedString {
        var attributed = AttributedString(content)
        for keyword in workspace.allKeywords where !keyword.isEmpty {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let range = attributed[searchRange].range(of: keyword, options: .caseInsensitive) {
                attributed[range].backgroundColor = .green.opacity(0.22)
                searchRange = range.upperBound..<attributed.endIndex
            }
        }
        return attributed
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ScreeningQueueRow: View {
    let reference: ImportedReference

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint(for: reference.consensusStatus))
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

private struct ScreeningVoteRow: View {
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

private struct ResultReferenceRow: View {
    let reference: ImportedReference

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                    .font(.headline)
                Spacer()
                StatusBadge(text: reference.consensusStatus.rawValue, tint: tint(for: reference.consensusStatus))
            }
            Text(reference.formattedAuthors)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let latestHuman = reference.humanVotes.last {
                Text("Human decision: \(latestHuman.decision.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

private struct ScreeningMetricCard: View {
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
