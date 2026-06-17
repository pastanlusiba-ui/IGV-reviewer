import SwiftUI
import UniformTypeIdentifiers

private enum SearchWorkspaceTab: String, CaseIterable, Identifiable {
    case strategy = "Strategy"
    case results = "Results"

    var id: String { rawValue }
}

struct ProjectSearchWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail

    @State private var workspace = SearchWorkspace()
    @State private var activeTab: SearchWorkspaceTab = .strategy
    @State private var isImporterPresented = false
    @State private var importMessage = ""
    @State private var expandedReferenceIDs: Set<String> = []
    @State private var showClearConfirmation = false
    @State private var sortOption: SearchSortOption = .newest

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Stage", selection: $activeTab) {
                ForEach(SearchWorkspaceTab.allCases) { tab in
                    if tab == .results {
                        Text("\(tab.rawValue) (\(workspace.importedReferences.count))").tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if activeTab == .strategy {
                strategyView
            } else {
                resultsView
            }

            footer
        }
        .frame(minWidth: 1020, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            workspace = appState.searchWorkspace(for: project)
        }
        .onDisappear {
            persistWorkspace()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.text, .plainText, .utf8PlainText, .xml, .json, .data, .ris, .bibtex, .endnote, .nbib],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Clear imported references?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                workspace.importedReferences.removeAll()
                persistWorkspace()
                importMessage = "Imported references cleared."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local imported reference list for this project.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Search & Import")
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

            Text("Build the search strategy with your team first. AI can help draft synonyms or summarize imported studies later, but humans approve the strategy, document the databases searched, and decide when the project is ready for screening.")
                .foregroundStyle(.secondary)

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.90, blue: 0.82), Color(red: 0.87, green: 0.92, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var strategyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                humanGuardrailsCard
                strategyBuilderCard
                databaseDocumentationCard
            }
            .padding(24)
        }
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                resultsSummaryCard
                importedReferencesCard
            }
            .padding(24)
        }
    }

    private var humanGuardrailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Human Review Guardrails", systemImage: "person.crop.rectangle.stack.fill")
                .font(.title3.weight(.semibold))
            Text("Use this stage to lock in your question, key concepts, and exact database strings. If you ask AI for wording help, reviewers should still verify terminology, synonyms, and inclusion relevance before screening begins.")
                .foregroundStyle(.secondary)
            if appState.aiConnections.isEmpty {
                Text("No AI providers are connected yet. That is fine for this stage; search setup remains fully usable without AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(appState.aiConnections.count) AI provider connection(s) available for later drafting and support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var strategyBuilderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Strategy Builder")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Add Concept") {
                    workspace.searchConcepts.append(SearchConcept(category: "New Concept"))
                }
                .buttonStyle(.bordered)
            }

            ForEach(Array(workspace.searchConcepts.enumerated()), id: \.element.id) { index, _ in
                SearchConceptEditorRow(
                    concept: $workspace.searchConcepts[index],
                    onDelete: {
                        workspace.searchConcepts.remove(at: index)
                    }
                )
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var databaseDocumentationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Database Documentation")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Add Database") {
                    workspace.databaseSearches.append(DatabaseSearch(databaseName: "New Database"))
                }
                .buttonStyle(.bordered)
            }

            ForEach(Array(workspace.databaseSearches.enumerated()), id: \.element.id) { index, _ in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Database name", text: $workspace.databaseSearches[index].databaseName)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            workspace.databaseSearches.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }

                    TextEditor(text: $workspace.databaseSearches[index].strategy)
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.25))
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var resultsSummaryCard: some View {
        HStack(spacing: 16) {
            SearchMetricCard(
                title: "Imported",
                value: "\(workspace.importedReferences.count)",
                subtitle: "references ready for review"
            )
            SearchMetricCard(
                title: "Concepts",
                value: "\(workspace.searchConcepts.count)",
                subtitle: "human-defined search concepts"
            )
            SearchMetricCard(
                title: "Databases",
                value: "\(workspace.databaseSearches.count)",
                subtitle: "documented search sources"
            )
        }
    }

    private var importedReferencesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Imported References")
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(SearchSortOption.allCases) { option in
                        Button(option.rawValue) {
                            sortOption = option
                        }
                    }
                } label: {
                    Label("Sort: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.bordered)

                Button("Clear", role: .destructive) {
                    showClearConfirmation = true
                }
                .buttonStyle(.bordered)

                Button("Upload References") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
            }

            if workspace.importedReferences.isEmpty {
                ContentUnavailableView(
                    "No References Imported",
                    systemImage: "doc.badge.plus",
                    description: Text("Upload RIS, BibTeX, EndNote, NBIB, or plain text exports. Reviewers should confirm what was imported before moving to screening.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedReferences) { reference in
                        SearchReferenceRow(
                            reference: reference,
                            isExpanded: expandedReferenceIDs.contains(reference.id),
                            keywords: workspace.allKeywords
                        ) {
                            if expandedReferenceIDs.contains(reference.id) {
                                expandedReferenceIDs.remove(reference.id)
                            } else {
                                expandedReferenceIDs.insert(reference.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack {
            Text("This stage is complete when humans approve the search plan and confirm the imported studies.")
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

    private var sortedReferences: [ImportedReference] {
        switch sortOption {
        case .newest:
            return workspace.importedReferences.sorted { lhs, rhs in
                lhs.customID > rhs.customID
            }
        case .oldest:
            return workspace.importedReferences.sorted { lhs, rhs in
                lhs.customID < rhs.customID
            }
        case .title:
            return workspace.importedReferences.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            var importedCount = 0
            var nextID = workspace.importedReferences.count + 1

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let references = try ReferenceImportService.importReferences(from: url, startingAt: nextID)
                nextID += references.count
                importedCount += references.count
                workspace.importedReferences.append(contentsOf: references)
            }

            activeTab = .results
            persistWorkspace()
            importMessage = importedCount == 0 ? "No references were detected in the selected files." : "Added \(importedCount) reference(s)."
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func persistWorkspace() {
        appState.saveSearchWorkspace(workspace, for: project.id)
    }
}

private struct SearchConceptEditorRow: View {
    @Binding var concept: SearchConcept
    let onDelete: () -> Void

    @State private var newSynonym = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Concept label", text: $concept.category)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            TextField("Core keyword or phrase", text: $concept.term)
                .textFieldStyle(.roundedBorder)

            if !concept.synonyms.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(concept.synonyms, id: \.self) { synonym in
                        Button {
                            concept.synonyms.removeAll { $0 == synonym }
                        } label: {
                            HStack(spacing: 6) {
                                Text(synonym)
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                TextField("Add synonym", text: $newSynonym)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addSynonym)
                Button("Add", action: addSynonym)
                    .buttonStyle(.borderedProminent)
                    .disabled(newSynonym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func addSynonym() {
        let trimmed = newSynonym.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        concept.synonyms.append(trimmed)
        newSynonym = ""
    }
}

private struct SearchReferenceRow: View {
    let reference: ImportedReference
    let isExpanded: Bool
    let keywords: [String]
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text("ID \(reference.customID)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                Text(reference.displayDate)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                .font(.headline)
            Text(reference.formattedAuthors)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isExpanded {
                Divider()

                if !reference.doi.isEmpty {
                    metadataRow(title: "DOI", value: reference.doi)
                }
                if !reference.url.isEmpty {
                    metadataRow(title: "URL", value: reference.url)
                }
                if !reference.sourceFormat.isEmpty {
                    metadataRow(title: "Imported from", value: reference.sourceFormat)
                }
                if !reference.cleanAbstract.isEmpty {
                    Text("Abstract")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(highlight(reference.cleanAbstract, keywords: keywords))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private func highlight(_ content: String, keywords: [String]) -> AttributedString {
        var attributed = AttributedString(content)
        for keyword in keywords where !keyword.isEmpty {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let range = attributed[searchRange].range(of: keyword, options: .caseInsensitive) {
                attributed[range].backgroundColor = .green.opacity(0.22)
                searchRange = range.upperBound..<attributed.endIndex
            }
        }
        return attributed
    }
}

private struct SearchMetricCard: View {
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

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
