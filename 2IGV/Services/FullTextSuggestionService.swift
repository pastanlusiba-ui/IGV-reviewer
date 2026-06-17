import Foundation

enum FullTextSuggestionService {
    static func generateSuggestions(
        for reference: ImportedReference,
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> [ScreeningVote] {
        let liveSuggestions = await LiveAISuggestionService.fullTextSuggestions(
            for: reference,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        )
        if !liveSuggestions.isEmpty {
            return liveSuggestions
        }

        guard reference.pdfURL != nil else {
            return [
                ScreeningVote(
                    screenerName: "ChatGPT Assistant",
                    decision: .insufficientInfo,
                    reason: "No PDF is attached yet, so this should not move forward without a human obtaining the full text.",
                    criterionUsed: "Full text missing",
                    isAI: true
                ),
                ScreeningVote(
                    screenerName: "Gemini Assistant",
                    decision: .insufficientInfo,
                    reason: "A reviewer needs the full text before an inclusion recommendation can be trusted.",
                    criterionUsed: "Full text missing",
                    isAI: true
                )
            ]
        }

        let normalized = "\(reference.title) \(reference.cleanAbstract)".lowercased()
        let likelyExcludeTerms = ["protocol", "editorial", "commentary", "animal", "letter"]
        let likelyIncludeTerms = ["trial", "cohort", "participant", "outcome", "intervention", "community", "pregnan", "malaria", "hiv"]

        let includeHits = likelyIncludeTerms.filter { normalized.contains($0) }.count
        let excludeHits = likelyExcludeTerms.filter { normalized.contains($0) }.count

        let firstDecision: ScreeningDecision = includeHits >= excludeHits ? .included : .excluded
        let secondDecision: ScreeningDecision = abs(includeHits - excludeHits) <= 1
            ? (firstDecision == .included ? .excluded : .included)
            : firstDecision

        return [
            ScreeningVote(
                screenerName: "ChatGPT Assistant",
                decision: firstDecision,
                reason: reason(for: firstDecision),
                criterionUsed: firstDecision == .included ? "Appears relevant in full text context" : "Appears out of scope in full text context",
                isAI: true
            ),
            ScreeningVote(
                screenerName: "Gemini Assistant",
                decision: secondDecision,
                reason: reason(for: secondDecision),
                criterionUsed: secondDecision == .included ? "Appears relevant in full text context" : "Appears out of scope in full text context",
                isAI: true
            )
        ]
    }

    private static func reason(for decision: ScreeningDecision) -> String {
        switch decision {
        case .included:
            return "The study still appears relevant at full-text stage, but a human reviewer should verify methods, population, and outcome fit."
        case .excluded:
            return "The study may fall outside scope at full-text stage, but a human reviewer should confirm before exclusion is finalized."
        case .insufficientInfo:
            return "There is not enough information for a confident full-text suggestion."
        case .conflict, .unknown:
            return "Automated signals are mixed, so a human decision is required."
        }
    }
}
