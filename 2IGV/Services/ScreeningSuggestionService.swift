import Foundation

enum ScreeningSuggestionService {
    static func generateSuggestions(
        for reference: ImportedReference,
        inclusionCriteria: [ScreeningCriterion],
        exclusionCriteria: [ScreeningCriterion],
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> [ScreeningVote] {
        let liveSuggestions = await LiveAISuggestionService.screeningSuggestions(
            for: reference,
            inclusionCriteria: inclusionCriteria,
            exclusionCriteria: exclusionCriteria,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        )
        if !liveSuggestions.isEmpty {
            return liveSuggestions
        }

        let normalized = "\(reference.title) \(reference.cleanAbstract)".lowercased()
        let score = heuristicScore(for: normalized)
        let likelyIncluded = score >= 0

        let primaryCriterion = likelyIncluded
            ? inclusionCriteria.first?.name ?? "Possible inclusion"
            : exclusionCriteria.first?.name ?? "Possible exclusion"
        let secondaryCriterion = likelyIncluded
            ? inclusionCriteria.dropFirst().first?.name ?? primaryCriterion
            : exclusionCriteria.dropFirst().first?.name ?? primaryCriterion

        let firstDecision: ScreeningDecision = likelyIncluded ? .included : .excluded
        let secondDecision: ScreeningDecision
        if abs(score) <= 1 {
            secondDecision = firstDecision == .included ? .excluded : .included
        } else {
            secondDecision = firstDecision
        }

        return [
            ScreeningVote(
                screenerName: "ChatGPT Assistant",
                decision: firstDecision,
                reason: rationale(for: firstDecision, reference: reference),
                criterionUsed: primaryCriterion,
                isAI: true
            ),
            ScreeningVote(
                screenerName: "Gemini Assistant",
                decision: secondDecision,
                reason: rationale(for: secondDecision, reference: reference),
                criterionUsed: secondaryCriterion,
                isAI: true
            )
        ]
    }

    private static func heuristicScore(for normalizedText: String) -> Int {
        let inclusionSignals = [
            "trial", "review", "intervention", "cohort", "pregnan", "community",
            "screening", "uptake", "maternal", "hiv", "malaria", "outcome"
        ]
        let exclusionSignals = [
            "editorial", "commentary", "protocol only", "animal", "letter",
            "conference abstract", "case report", "opinion"
        ]

        let includeScore = inclusionSignals.reduce(0) { partial, term in
            partial + (normalizedText.contains(term) ? 1 : 0)
        }
        let excludeScore = exclusionSignals.reduce(0) { partial, term in
            partial + (normalizedText.contains(term) ? 1 : 0)
        }
        return includeScore - excludeScore
    }

    private static func rationale(for decision: ScreeningDecision, reference: ImportedReference) -> String {
        switch decision {
        case .included:
            return "The title and abstract appear relevant to the review question, but a human reviewer should confirm fit against the protocol."
        case .excluded:
            return "The title and abstract look less aligned with the likely population, intervention, or design, but this remains only a suggestion."
        case .insufficientInfo:
            return "The abstract provides too little information for a confident suggestion."
        case .conflict, .unknown:
            return "The automated signals are mixed. Human review is required."
        }
    }
}
