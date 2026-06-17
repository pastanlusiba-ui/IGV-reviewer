import SwiftUI

private enum ExtractionWorkspaceTab: String, CaseIterable, Identifiable {
    case extraction = "Extraction"
    case quality = "Quality"
    case configure = "Configure"

    var id: String { rawValue }
}

struct ProjectExtractionWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail

    @State private var workspace = SearchWorkspace()
    @State private var activeTab: ExtractionWorkspaceTab = .extraction
    @State private var selectedReferenceID: String?
    @State private var newQualityName = ""
    @State private var newQualityDescription = ""
    @State private var newSectionName = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Extraction workspace", selection: $activeTab) {
                ForEach(ExtractionWorkspaceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            switch activeTab {
            case .extraction:
                extractionView
            case .quality:
                qualityView
            case .configure:
                configureView
            }

            footer
        }
        .frame(minWidth: 1220, minHeight: 820)
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
                    Text("4. Data Extraction & QA")
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

            Text("Keep this stage reviewer-authored. AI can help draft or summarize later, but humans should capture the extracted values, supporting evidence, and quality judgments.")
                .foregroundStyle(.secondary)

            let counts = workspace.extractionCompletionCounts
            HStack(spacing: 12) {
                StatusBadge(text: "\(counts.eligible) Included", tint: .blue)
                StatusBadge(text: "\(counts.completed) Extracted", tint: .green)
                StatusBadge(text: "\(counts.qaStarted) QA Started", tint: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.90, green: 0.90, blue: 0.82), Color(red: 0.84, green: 0.92, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var extractionView: some View {
        Group {
            if eligibleReferences.isEmpty {
                ContentUnavailableView(
                    "No Studies Ready for Extraction",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Move studies through full-text review first. Only full-text includes appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        extractionSidebar
                            .frame(width: geo.size.width * 0.22)
                        Divider()
                        extractionEvidencePanel
                            .frame(width: geo.size.width * 0.33)
                        Divider()
                        extractionFormPanel
                            .frame(width: geo.size.width * 0.45)
                    }
                }
            }
        }
    }

    private var qualityView: some View {
        Group {
            if eligibleReferences.isEmpty {
                ContentUnavailableView(
                    "No QA Items Yet",
                    systemImage: "checkmark.shield",
                    description: Text("Quality appraisal becomes available once a study is included at full-text stage.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        extractionSidebar
                            .frame(width: geo.size.width * 0.25)
                        Divider()
                        qualityDetailPanel
                            .frame(width: geo.size.width * 0.75)
                    }
                }
            }
        }
    }

    private var extractionSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Included Studies")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(eligibleReferences.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            List(selection: Binding(
                get: { selectedReferenceID },
                set: { selectedReferenceID = $0 }
            )) {
                ForEach(eligibleReferences) { reference in
                    ExtractionReferenceRow(
                        reference: reference,
                        isComplete: reference.hasExtractionData,
                        hasQA: reference.hasQualityAssessment
                    )
                    .tag(reference.id)
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var extractionEvidencePanel: some View {
        Group {
            if let reference = selectedReference {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                            .font(.title3.weight(.semibold))
                        Text(reference.formattedAuthors)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            if !reference.publicationYear.isEmpty {
                                StatusBadge(text: reference.publicationYear, tint: .gray)
                            }
                            StatusBadge(text: reference.fullTextConsensusStatus.rawValue, tint: .green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()

                    if let pdfURL = reference.pdfURL {
                        PDFPreviewView(url: pdfURL)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No PDF Attached",
                                systemImage: "doc",
                                description: Text("The reviewer can still record extraction notes here, but linking a PDF in full-text review makes evidence capture easier.")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(20)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Study",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Choose an included study to review the full text and capture structured extraction data.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var extractionFormPanel: some View {
        Group {
            if let referenceIndex = selectedReferenceIndex {
                Form {
                    Section {
                        LabeledContent("Study ID") {
                            TextField(
                                "Reference ID",
                                text: Binding(
                                    get: { workspace.importedReferences[referenceIndex].customID },
                                    set: { workspace.importedReferences[referenceIndex].customID = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                        }

                        LabeledContent("Study title") {
                            TextField(
                                "Study title",
                                text: Binding(
                                    get: { workspace.importedReferences[referenceIndex].title },
                                    set: { workspace.importedReferences[referenceIndex].title = $0 }
                                ),
                                axis: .vertical
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    } header: {
                        Text("General information")
                    } footer: {
                        Text("These values remain editable so the reviewer can correct imported metadata while extracting.")
                    }

                    ForEach(workspace.extractionFields) { field in
                        ExtractionFieldFormRow(
                            reference: Binding(
                                get: { workspace.importedReferences[referenceIndex] },
                                set: { workspace.importedReferences[referenceIndex] = $0 }
                            ),
                            field: field
                        )
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "Select a Study",
                    systemImage: "square.and.pencil",
                    description: Text("Choose an included study to enter extracted values and evidence notes.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var qualityDetailPanel: some View {
        Group {
            if let referenceIndex = selectedReferenceIndex {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workspace.importedReferences[referenceIndex].title.isEmpty ? "Untitled reference" : workspace.importedReferences[referenceIndex].title)
                                .font(.title3.weight(.semibold))
                            Text("Quality judgments remain reviewer-owned. Use these ratings to capture risk or confidence concerns transparently.")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(workspace.qualityCriteria) { criterion in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(criterion.name)
                                    .font(.headline)
                                Text(criterion.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Picker(
                                    criterion.name,
                                    selection: Binding(
                                        get: { workspace.importedReferences[referenceIndex].qualityData[criterion.id] ?? .unclear },
                                        set: { workspace.importedReferences[referenceIndex].qualityData[criterion.id] = $0 }
                                    )
                                ) {
                                    ForEach(QualityAssessmentValue.allCases) { value in
                                        Text(value.rawValue).tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(20)
                            .background(cardBackground)
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Select a Study",
                    systemImage: "checkmark.rectangle",
                    description: Text("Choose an included study to record structured quality judgments.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var configureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Extraction form")
                        .font(.title3.weight(.semibold))

                    if workspace.extractionFields.isEmpty {
                        Text("No extraction fields configured yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ExtractionFieldDesigner(fields: $workspace.extractionFields)
                    }

                    HStack {
                        TextField("New section name", text: $newSectionName)
                            .textFieldStyle(.roundedBorder)
                        Button("Add Section") {
                            workspace.extractionFields.append(
                                ExtractionField(
                                    name: newSectionName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    description: "Add a short note explaining what this section captures.",
                                    type: .section
                                )
                            )
                            newSectionName = ""
                            persistWorkspace()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Quality criteria")
                        .font(.title3.weight(.semibold))

                    ForEach(workspace.qualityCriteria) { criterion in
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
                                workspace.qualityCriteria.removeAll { $0.id == criterion.id }
                                persistWorkspace()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        Divider()
                    }

                    TextField("New quality criterion", text: $newQualityName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Quality description", text: $newQualityDescription)
                        .textFieldStyle(.roundedBorder)
                    Button("Add Quality Criterion") {
                        workspace.qualityCriteria.append(
                            QualityCriterion(
                                name: newQualityName.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: newQualityDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        newQualityName = ""
                        newQualityDescription = ""
                        persistWorkspace()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newQualityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
                .background(cardBackground)
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            Text("Extracted values, evidence notes, and QA judgments stay editable. Human review remains the authoritative source of truth.")
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

    private var eligibleReferences: [ImportedReference] {
        workspace.importedReferences.filter(\.isEligibleForExtraction)
    }

    private var selectedReference: ImportedReference? {
        guard let selectedReferenceID else { return nil }
        return workspace.importedReferences.first { $0.id == selectedReferenceID }
    }

    private var selectedReferenceIndex: Int? {
        guard let selectedReferenceID else { return nil }
        return workspace.importedReferences.firstIndex { $0.id == selectedReferenceID }
    }

    private func autoSelectReference() {
        if selectedReferenceID == nil {
            selectedReferenceID = eligibleReferences.first?.id
        }
    }

    private func persistWorkspace() {
        appState.saveSearchWorkspace(workspace, for: project.id)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ExtractionReferenceRow: View {
    let reference: ImportedReference
    let isComplete: Bool
    let hasQA: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isComplete ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(reference.customID.isEmpty ? "No ID" : "Ref \(reference.customID)")
                    if hasQA {
                        Text("QA")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExtractionFieldFormRow: View {
    @Binding var reference: ImportedReference
    let field: ExtractionField

    @State private var isShowingEvidence = false

    var body: some View {
        if field.isSection {
            Section {
                ForEach(field.children) { child in
                    ExtractionFieldFormRow(reference: $reference, field: child)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.name)
                    if !field.description.isEmpty {
                        Text(field.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.name)
                            .font(.headline)
                        if !field.description.isEmpty {
                            Text(field.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(isShowingEvidence ? "Hide evidence" : "Add evidence") {
                        isShowingEvidence.toggle()
                    }
                    .buttonStyle(.bordered)
                }

                TextField(
                    field.type == .number ? "Enter a numeric value" : "Enter extracted value",
                    text: valueBinding
                )
                .textFieldStyle(.roundedBorder)

                if isShowingEvidence || !(reference.extractionExcerpts[field.id] ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Evidence / excerpt")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextEditor(text: excerptBinding)
                            .frame(height: 90)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                    }
                }

                if !field.children.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(field.children) { child in
                            ExtractionFieldFormRow(reference: $reference, field: child)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { reference.extractionData[field.id] ?? "" },
            set: { reference.extractionData[field.id] = $0 }
        )
    }

    private var excerptBinding: Binding<String> {
        Binding(
            get: { reference.extractionExcerpts[field.id] ?? "" },
            set: { reference.extractionExcerpts[field.id] = $0 }
        )
    }
}

private struct ExtractionFieldDesigner: View {
    @Binding var fields: [ExtractionField]

    var body: some View {
        ForEach($fields) { $field in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: field.isSection ? "folder.fill" : "tag.fill")
                        .foregroundStyle(field.isSection ? .blue : .orange)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Field name", text: $field.name)
                            .textFieldStyle(.roundedBorder)
                        TextField("Description", text: $field.description)
                            .textFieldStyle(.roundedBorder)
                        if !field.isSection {
                            Picker("Type", selection: $field.type) {
                                ForEach(FieldType.allCases.filter { $0 != .section }) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 160)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) {
                        fields.removeAll { $0.id == field.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                if field.isSection {
                    ForEach($field.children) { $child in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Field name", text: $child.name)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Description", text: $child.description)
                                    .textFieldStyle(.roundedBorder)
                                Picker("Type", selection: $child.type) {
                                    ForEach(FieldType.allCases.filter { $0 != .section }) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 160)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                field.children.removeAll { $0.id == child.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                    }

                    Button("Add Field to Section") {
                        field.children.append(
                            ExtractionField(
                                name: "New field",
                                description: "Describe what reviewers should capture here.",
                                type: .text
                            )
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
        }
    }
}
