import Foundation

enum DraftAssistanceService {
    static func draftSynthesis(
        for field: ExtractionField,
        references: [ImportedReference],
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> DraftSuggestion {
        let evidence = synthesisEvidenceText(for: field, references: references)
        let prompt = """
        Draft a cautious synthesis paragraph for the variable "\(field.name)".
        Use only the provided extracted evidence.
        Do not invent findings, statistics, or certainty claims that are not present.
        Keep the tone suitable for a human reviewer to edit.
        """

        if let liveDraft = await LiveAISuggestionService.assistText(
            taskPrompt: prompt,
            sourceMaterial: evidence,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        ) {
            return DraftSuggestion(content: liveDraft, source: "Live AI draft")
        }

        return DraftSuggestion(
            content: localSynthesisFallback(for: field, evidence: evidence),
            source: "Local draft fallback"
        )
    }

    static func draftReportSection(
        title: String,
        workspace: SearchWorkspace,
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> DraftSuggestion {
        let sourceMaterial = reportEvidenceText(title: title, workspace: workspace)
        let prompt = """
        Draft the systematic review report section "\(title)".
        Base the draft only on the supplied project material.
        Keep it concise, cautious, and ready for human editing.
        """

        if let liveDraft = await LiveAISuggestionService.assistText(
            taskPrompt: prompt,
            sourceMaterial: sourceMaterial,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        ) {
            return DraftSuggestion(content: liveDraft, source: "Live AI draft")
        }

        return DraftSuggestion(
            content: localReportFallback(title: title, sourceMaterial: sourceMaterial),
            source: "Local draft fallback"
        )
    }

    private static func synthesisEvidenceText(for field: ExtractionField, references: [ImportedReference]) -> String {
        references.compactMap { reference -> String? in
            guard let value = reference.extractionData[field.id],
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let excerpt = reference.extractionExcerpts[field.id]
                .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ?? "No excerpt recorded."

            return """
            Study: \(reference.title.isEmpty ? "Untitled study" : reference.title)
            Authors: \(reference.formattedAuthors)
            Year: \(reference.publicationYear)
            Extracted value: \(value)
            Evidence excerpt: \(excerpt)
            """
        }
        .joined(separator: "\n\n")
    }

    private static func reportEvidenceText(title: String, workspace: SearchWorkspace) -> String {
        let synthesisText = workspace.allFlatFields.compactMap { field -> String? in
            guard let text = workspace.variableSynthesis[field.id],
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return "\(field.name): \(text)"
        }
        .joined(separator: "\n")

        let references = CitationFormattingService.bibliography(
            for: workspace.includedReferencesForReporting,
            style: workspace.reportCitationStyle
        )

        return """
        Review title: \(workspace.reportTitleSection)
        Review question context:
        \(workspace.searchConcepts.map { "\($0.category): \($0.term)" }.joined(separator: "\n"))

        Existing synthesis:
        \(synthesisText)

        Existing report content:
        Abstract: \(workspace.reportAbstract)
        Introduction: \(workspace.reportIntroduction)
        Methods: \(workspace.reportMethods)
        Results: \(workspace.reportResults)
        Discussion: \(workspace.reportDiscussion)

        Citations:
        \(references)

        Requested section: \(title)
        """
    }

    private static func localSynthesisFallback(for field: ExtractionField, evidence: String) -> String {
        if evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No extracted evidence has been recorded yet for \(field.name.lowercased()). Add reviewer-checked extraction first."
        }

        let lines = evidence
            .components(separatedBy: "\n\n")
            .prefix(3)
            .map { block in
                let compact = block.replacingOccurrences(of: "\n", with: " ")
                return "- \(compact)"
            }
            .joined(separator: "\n")

        return """
        The currently extracted evidence for \(field.name.lowercased()) suggests the following reviewer-noted patterns:
        \(lines)

        A reviewer should now refine this draft into a balanced synthesis, checking wording against the original studies before using it in reporting.
        """
    }

    private static func localReportFallback(title: String, sourceMaterial: String) -> String {
        let trimmed = sourceMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No source material is available yet for the \(title.lowercased()) section. Complete synthesis and reviewer notes first."
        }

        return """
        Draft \(title):

        This section should be finalized by a human reviewer using the synthesized evidence already captured in the project. The current project notes provide enough material to begin drafting, but the wording, emphasis, and interpretation should still be checked carefully against the extracted studies and citations.
        """
    }
}

struct DraftSuggestion {
    let content: String
    let source: String
}
