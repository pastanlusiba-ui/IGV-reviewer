import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var wordDocument: UTType {
        UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    }
}

private struct ReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.wordDocument] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        self.text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 12)]
        )
        let range = NSRange(location: 0, length: attributed.length)
        let data = try attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        self.text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private enum ReportSectionID: String, CaseIterable, Identifiable {
    case title = "Title"
    case keywords = "Keywords"
    case abstract = "Abstract"
    case introduction = "Introduction"
    case methods = "Methods"
    case results = "Results"
    case discussion = "Discussion"
    case references = "References"
    case appendices = "Appendices"

    var id: String { rawValue }

    var minHeight: CGFloat {
        switch self {
        case .title, .keywords:
            return 100
        case .abstract:
            return 140
        case .references, .appendices:
            return 180
        case .results:
            return 260
        case .introduction, .methods, .discussion:
            return 220
        }
    }
}

struct ProjectReportWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail

    @State private var workspace = SearchWorkspace()
    @State private var isExporting = false
    @State private var citationExportFormat: CitationExportFormat = .ris
    @State private var isExportingCitations = false
    @State private var draftSuggestions: [ReportSectionID: DraftSuggestion] = [:]
    @State private var generatingSections: Set<ReportSectionID> = []

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                HStack(spacing: 0) {
                    reportSupportSidebar
                        .frame(width: geo.size.width * 0.34)
                    Divider()
                    reportEditor
                        .frame(width: geo.size.width * 0.66)
                }
            }

            footer
        }
        .frame(minWidth: 1260, minHeight: 880)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            workspace = appState.searchWorkspace(for: project)
            seedReportIfNeeded()
        }
        .onDisappear {
            persistWorkspace()
        }
        .fileExporter(
            isPresented: $isExporting,
            document: ReportDocument(text: reportExportText),
            contentType: .wordDocument,
            defaultFilename: exportFilename
        ) { _ in }
        .fileExporter(
            isPresented: $isExportingCitations,
            document: PlainTextDocument(text: citationExportText),
            contentType: .plainText,
            defaultFilename: "\(exportFilename)_references.\(citationExportFormat.filenameExtension)"
        ) { _ in }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("6. Report Writing")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(project.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Build Bibliography") {
                    workspace.reportReferences = CitationFormattingService.bibliography(
                        for: workspace.includedReferencesForReporting,
                        style: workspace.reportCitationStyle
                    )
                    persistWorkspace()
                }
                .buttonStyle(.bordered)
                Button("Export Report") {
                    isExporting = true
                }
                .buttonStyle(.borderedProminent)
                Menu("Export Citations") {
                    Button("RIS Library") {
                        citationExportFormat = .ris
                        isExportingCitations = true
                    }
                    Button("BibTeX Library") {
                        citationExportFormat = .bibTeX
                        isExportingCitations = true
                    }
                }
                .menuStyle(.borderlessButton)
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Text("Write the report with the extracted data, citations, and synthesis drafts in view. AI may propose draft text, but a human should explicitly accept or reject it before export.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusBadge(text: "\(workspace.synthesizedFieldCount) Syntheses", tint: .blue)
                StatusBadge(text: "\(workspace.reportSectionCompletionCount) Sections drafted", tint: .green)
                StatusBadge(text: workspace.reportCitationStyle.rawValue, tint: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.90, blue: 0.84), Color(red: 0.88, green: 0.93, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var reportSupportSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                citationManagerCard
                synthesisSupportCard
                includedStudiesCard
            }
            .padding(24)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var citationManagerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Citations & References")
                .font(.title3.weight(.semibold))

            Picker("Citation style", selection: $workspace.reportCitationStyle) {
                ForEach(CitationStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text("Manage the bibliography explicitly here so exported reports reflect reviewer-selected sources and style.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Build References") {
                    workspace.reportReferences = CitationFormattingService.bibliography(
                        for: workspace.includedReferencesForReporting,
                        style: workspace.reportCitationStyle
                    )
                    persistWorkspace()
                }
                .buttonStyle(.borderedProminent)

                Button("Clear References") {
                    workspace.reportReferences = ""
                    persistWorkspace()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Export RIS") {
                    citationExportFormat = .ris
                    isExportingCitations = true
                }
                .buttonStyle(.bordered)

                Button("Export BibTeX") {
                    citationExportFormat = .bibTeX
                    isExportingCitations = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var synthesisSupportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synthesized Data")
                .font(.title3.weight(.semibold))

            if workspace.synthesizedFieldCount == 0 {
                Text("No synthesis drafts yet. Draft synthesis notes first so they can support the report narrative.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workspace.allFlatFields) { field in
                    if let synthesis = workspace.variableSynthesis[field.id],
                       !synthesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field.name)
                                .font(.headline)
                            Text(synthesis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var includedStudiesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Included Studies")
                .font(.title3.weight(.semibold))

            if workspace.includedReferencesForReporting.isEmpty {
                Text("No included studies are available yet for citation management.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(workspace.includedReferencesForReporting.enumerated()), id: \.element.id) { index, reference in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reference.title.isEmpty ? "Untitled reference" : reference.title)
                            .font(.headline)
                        Text(CitationFormattingService.formattedCitation(for: reference, style: workspace.reportCitationStyle, index: index + 1))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        HStack {
                            Button("Append Citation") {
                                appendCitation(reference, index: index + 1)
                            }
                            .buttonStyle(.bordered)
                            Button("Append In-Text") {
                                appendInTextCitation(reference, index: index + 1)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if reference.id != workspace.includedReferencesForReporting.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var reportEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(ReportSectionID.allCases) { section in
                    reportSectionCard(section)
                }
            }
            .padding(30)
        }
    }

    private func reportSectionCard(_ section: ReportSectionID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.rawValue)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(generatingSections.contains(section) ? "Drafting..." : "Draft with AI") {
                    generateDraft(for: section)
                }
                .buttonStyle(.bordered)
                .disabled(generatingSections.contains(section))
            }

            if let proposal = draftSuggestions[section] {
                VStack(alignment: .leading, spacing: 10) {
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
                            setText(for: section, to: proposal.content)
                            draftSuggestions[section] = nil
                            persistWorkspace()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Discard Draft") {
                            draftSuggestions[section] = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }

            TextEditor(text: binding(for: section))
                .frame(minHeight: section.minHeight)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
        }
        .padding(22)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack {
            Text("Report export is a draft artifact. Review the content, citations, and interpretation carefully before sharing it externally.")
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

    private func seedReportIfNeeded() {
        if workspace.reportTitleSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workspace.reportTitleSection = project.title
        }
        if workspace.reportResults.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           workspace.synthesizedFieldCount > 0 {
            let sections = workspace.allFlatFields.compactMap { field -> String? in
                guard let synthesis = workspace.variableSynthesis[field.id],
                      !synthesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return "## \(field.name)\n\(synthesis)"
            }
            workspace.reportResults = sections.joined(separator: "\n\n")
        }
    }

    private func appendCitation(_ reference: ImportedReference, index: Int) {
        let citation = CitationFormattingService.formattedCitation(
            for: reference,
            style: workspace.reportCitationStyle,
            index: index
        )
        if workspace.reportReferences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workspace.reportReferences = citation
        } else if !workspace.reportReferences.contains(citation) {
            workspace.reportReferences += "\n\n\(citation)"
        }
        persistWorkspace()
    }

    private func appendInTextCitation(_ reference: ImportedReference, index: Int) {
        let citation = CitationFormattingService.inTextCitation(
            for: reference,
            style: workspace.reportCitationStyle,
            index: index
        )
        let current = workspace.reportResults.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.reportResults = current.isEmpty ? citation : "\(current) \(citation)"
        persistWorkspace()
    }

    private func generateDraft(for section: ReportSectionID) {
        generatingSections.insert(section)

        Task {
            let draft = await DraftAssistanceService.draftReportSection(
                title: section.rawValue,
                workspace: workspace,
                connections: appState.aiConnections,
                apiKeyLookup: { connection in
                    appState.storedAPIKey(for: connection)
                }
            )

            await MainActor.run {
                draftSuggestions[section] = draft
                generatingSections.remove(section)
            }
        }
    }

    private func binding(for section: ReportSectionID) -> Binding<String> {
        Binding(
            get: { text(for: section) },
            set: { setText(for: section, to: $0) }
        )
    }

    private func text(for section: ReportSectionID) -> String {
        switch section {
        case .title:
            return workspace.reportTitleSection
        case .keywords:
            return workspace.reportKeywords
        case .abstract:
            return workspace.reportAbstract
        case .introduction:
            return workspace.reportIntroduction
        case .methods:
            return workspace.reportMethods
        case .results:
            return workspace.reportResults
        case .discussion:
            return workspace.reportDiscussion
        case .references:
            return workspace.reportReferences
        case .appendices:
            return workspace.reportAppendices
        }
    }

    private func setText(for section: ReportSectionID, to value: String) {
        switch section {
        case .title:
            workspace.reportTitleSection = value
        case .keywords:
            workspace.reportKeywords = value
        case .abstract:
            workspace.reportAbstract = value
        case .introduction:
            workspace.reportIntroduction = value
        case .methods:
            workspace.reportMethods = value
        case .results:
            workspace.reportResults = value
        case .discussion:
            workspace.reportDiscussion = value
        case .references:
            workspace.reportReferences = value
        case .appendices:
            workspace.reportAppendices = value
        }
    }

    private var reportExportText: String {
        [
            "TITLE: \(workspace.reportTitleSection)",
            "KEYWORDS: \(workspace.reportKeywords)",
            "ABSTRACT\n\(workspace.reportAbstract)",
            "1. INTRODUCTION\n\(workspace.reportIntroduction)",
            "2. METHODS\n\(workspace.reportMethods)",
            "3. RESULTS\n\(workspace.reportResults)",
            "4. DISCUSSION\n\(workspace.reportDiscussion)",
            "5. REFERENCES\n\(workspace.reportReferences)",
            "6. APPENDICES\n\(workspace.reportAppendices)"
        ]
        .joined(separator: "\n\n")
    }

    private var exportFilename: String {
        let raw = project.title.isEmpty ? "Review_Report" : project.title
        return raw.replacingOccurrences(of: "/", with: "-")
    }

    private var citationExportText: String {
        switch citationExportFormat {
        case .ris:
            return CitationFormattingService.ris(for: workspace.includedReferencesForReporting)
        case .bibTeX:
            return CitationFormattingService.bibTeX(for: workspace.includedReferencesForReporting)
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
