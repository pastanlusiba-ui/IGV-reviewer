import SwiftUI

struct ProjectSynthesisWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail

    @State private var workspace = SearchWorkspace()
    @State private var selectedFieldID: String?
    @State private var isGeneratingDraft = false
    @State private var draftSuggestion: DraftSuggestion?

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                HStack(spacing: 0) {
                    fieldSidebar
                        .frame(width: geo.size.width * 0.32)
                    Divider()
                    synthesisEditor
                        .frame(width: geo.size.width * 0.68)
                }
            }

            footer
        }
        .frame(minWidth: 1180, minHeight: 820)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            workspace = appState.searchWorkspace(for: project)
            if selectedFieldID == nil {
                selectedFieldID = workspace.allFlatFields.first?.id
            }
        }
        .onDisappear {
            persistWorkspace()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("5. Synthesis")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(project.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedField != nil {
                    Button(isGeneratingDraft ? "Drafting..." : "Draft with AI") {
                        generateDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingDraft)
                }
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Text("Synthesis should remain interpretation-led by the review team. Use the extracted values as the evidence base and write narrative summaries that can later feed the report.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusBadge(text: "\(workspace.allFlatFields.count) Variables", tint: .blue)
                StatusBadge(text: "\(workspace.synthesizedFieldCount) Synthesized", tint: .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.88, blue: 0.83), Color(red: 0.84, green: 0.90, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var fieldSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Variables")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(20)

            List(selection: Binding(
                get: { selectedFieldID },
                set: { selectedFieldID = $0 }
            )) {
                ForEach(workspace.allFlatFields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.name)
                            .font(.headline)
                        Text(field.description.isEmpty ? "No description" : field.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let text = workspace.variableSynthesis[field.id],
                           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Drafted")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(field.id)
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var synthesisEditor: some View {
        Group {
            if let selectedField {
                HStack(spacing: 0) {
                    extractedEvidencePanel(for: selectedField)
                        .frame(maxWidth: .infinity)
                    Divider()
                    synthesisDraftPanel(for: selectedField)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "Select a Variable",
                    systemImage: "list.bullet.indent",
                    description: Text("Choose an extraction variable to review the extracted evidence and draft its synthesis.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func extractedEvidencePanel(for field: ExtractionField) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Extracted Evidence")
                    .font(.title3.weight(.semibold))

                let refs = extractedReferences(for: field)
                if refs.isEmpty {
                    ContentUnavailableView(
                        "No Extracted Values",
                        systemImage: "tray",
                        description: Text("This variable does not have extracted values yet.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(refs) { reference in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                                .font(.headline)
                            Text(reference.extractionData[field.id] ?? "")
                                .textSelection(.enabled)
                            if let excerpt = reference.extractionExcerpts[field.id],
                               !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Divider()
                                Text("Evidence excerpt")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(excerpt)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
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

    private func synthesisDraftPanel(for field: ExtractionField) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(field.name)
                    .font(.title3.weight(.semibold))

                Text("Draft a human-reviewed synthesis for this variable. This text can later populate the report results section.")
                    .foregroundStyle(.secondary)

                if let proposal = draftSuggestion {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Draft Proposal")
                                .font(.headline)
                            Spacer()
                            StatusBadge(text: proposal.source, tint: .blue)
                        }
                        Text(proposal.content)
                            .textSelection(.enabled)
                        HStack {
                            Button("Accept Draft") {
                                guard let selectedField else { return }
                                workspace.variableSynthesis[selectedField.id] = proposal.content
                                self.draftSuggestion = nil
                                persistWorkspace()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Discard Draft") {
                                self.draftSuggestion = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(18)
                    .background(cardBackground)
                }

                TextEditor(text: synthesisBinding(for: field))
                    .frame(minHeight: 560)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            Text("Synthesis drafts should reflect reviewer interpretation of the extracted evidence, not raw AI output.")
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

    private var selectedField: ExtractionField? {
        guard let selectedFieldID else { return nil }
        return workspace.allFlatFields.first { $0.id == selectedFieldID }
    }

    private func extractedReferences(for field: ExtractionField) -> [ImportedReference] {
        workspace.importedReferences.filter { reference in
            let value = reference.extractionData[field.id] ?? ""
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func synthesisBinding(for field: ExtractionField) -> Binding<String> {
        Binding(
            get: { workspace.variableSynthesis[field.id] ?? "" },
            set: { workspace.variableSynthesis[field.id] = $0 }
        )
    }

    private func persistWorkspace() {
        appState.saveSearchWorkspace(workspace, for: project.id)
    }

    private func generateDraft() {
        guard let selectedField else { return }
        isGeneratingDraft = true

        Task {
            let draft = await DraftAssistanceService.draftSynthesis(
                for: selectedField,
                references: extractedReferences(for: selectedField),
                connections: appState.aiConnections,
                apiKeyLookup: { connection in
                    appState.storedAPIKey(for: connection)
                }
            )

            await MainActor.run {
                draftSuggestion = draft
                isGeneratingDraft = false
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}
