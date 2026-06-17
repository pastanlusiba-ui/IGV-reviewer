import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case gemini
    case perplexity
    case deepSeek = "deepseek"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "ChatGPT / OpenAI"
        case .gemini:
            return "Gemini"
        case .perplexity:
            return "Perplexity"
        case .deepSeek:
            return "DeepSeek"
        }
    }

    var shortDescription: String {
        switch self {
        case .openAI:
            return "Strong general-purpose reasoning and structured outputs."
        case .gemini:
            return "Google-hosted models with an official free tier in some environments."
        case .perplexity:
            return "Search-grounded responses and citation-friendly workflows."
        case .deepSeek:
            return "Low-cost reasoning and coding-friendly models."
        }
    }

    var pricingHeadline: String {
        switch self {
        case .openAI:
            return "API is billed separately from ChatGPT plans."
        case .gemini:
            return "Free tier may be available, with paid tiers for stronger limits."
        case .perplexity:
            return "API access is generally paid."
        case .deepSeek:
            return "Low-cost API, but not a guaranteed free tier."
        }
    }

    var managedAccessNote: String {
        switch self {
        case .openAI:
            return "Managed access depends on app-hosted credits or shared quotas."
        case .gemini:
            return "Managed access can map naturally to Gemini free-tier style usage."
        case .perplexity:
            return "Managed access may be limited because the provider is typically paid."
        case .deepSeek:
            return "Managed access may be low-cost, but not guaranteed free."
        }
    }
}

enum AIConnectionMode: String, Codable, CaseIterable, Identifiable {
    case managedAccess = "managed_access"
    case ownAPIKey = "own_api_key"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .managedAccess:
            return "Use app-managed/free-tier access"
        case .ownAPIKey:
            return "Connect my own API key"
        }
    }

    var description: String {
        switch self {
        case .managedAccess:
            return "Best for quick setup. Availability may depend on provider quotas or app-hosted credits."
        case .ownAPIKey:
            return "Best for higher limits, predictable usage, and provider-level control."
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "Match System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

struct AIConnection: Codable, Identifiable {
    let id: UUID
    var provider: AIProvider
    var mode: AIConnectionMode
    var label: String
    var createdAt: Date

    var modeLabel: String {
        switch mode {
        case .managedAccess:
            return "Managed"
        case .ownAPIKey:
            return "Own key"
        }
    }
}

enum ProjectStage: String, Codable, CaseIterable {
    case setup
    case search
    case screening
    case full_text = "full_text"
    case extraction
    case synthesis
    case reporting

    var label: String {
        switch self {
        case .setup: return "Setup"
        case .search: return "Search"
        case .screening: return "Screening"
        case .full_text: return "Full Text"
        case .extraction: return "Extraction"
        case .synthesis: return "Synthesis"
        case .reporting: return "Reporting"
        }
    }
}

enum ReviewProcessStage: String, Codable, CaseIterable, Identifiable, Hashable {
    case searching
    case screening
    case fullTextRetrieval = "full_text_retrieval"
    case fullTextScreening = "full_text_screening"
    case dataExtraction = "data_extraction"
    case synthesisQA = "synthesis_qa"
    case report

    var id: String { rawValue }

    var label: String {
        switch self {
        case .searching: return "Searching"
        case .screening: return "Screening"
        case .fullTextRetrieval: return "Full Text Retrieval"
        case .fullTextScreening: return "Full Text Screening"
        case .dataExtraction: return "Data Extraction"
        case .synthesisQA: return "Synthesis & QA"
        case .report: return "Report Writing"
        }
    }

    var shortLabel: String {
        switch self {
        case .searching: return "Search"
        case .screening: return "Screen"
        case .fullTextRetrieval: return "Retrieve"
        case .fullTextScreening: return "Full Text"
        case .dataExtraction: return "Extract"
        case .synthesisQA: return "QA"
        case .report: return "Report"
        }
    }
}

enum ProjectHealth: String, Codable {
    case onTrack = "on_track"
    case atRisk = "at_risk"
    case blocked

    var label: String {
        switch self {
        case .onTrack: return "On Track"
        case .atRisk: return "At Risk"
        case .blocked: return "Blocked"
        }
    }
}

enum MembershipRole: String, Codable, CaseIterable {
    case owner
    case editor
    case reviewer
    case viewer
}

enum JobStatus: String, Codable {
    case queued
    case running
    case completed
    case failed
}

struct UserSummary: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let title: String
}

struct MemberSummary: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let role: MembershipRole
    let assignedStages: [ReviewProcessStage]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case assignedStages = "assigned_stages"
    }

    init(
        id: String,
        name: String,
        email: String?,
        role: MembershipRole,
        assignedStages: [ReviewProcessStage] = ReviewProcessStage.allCases
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.assignedStages = assignedStages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        role = try container.decode(MembershipRole.self, forKey: .role)
        assignedStages = try container.decodeIfPresent([ReviewProcessStage].self, forKey: .assignedStages) ?? ReviewProcessStage.allCases
    }
}

struct AutomationJobSummary: Codable, Identifiable {
    let id: String
    let title: String
    let status: JobStatus
    let provider: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case provider
        case updatedAt = "updated_at"
    }
}

struct ProjectSummary: Codable, Identifiable {
    let id: String
    let title: String
    let reviewQuestion: String
    let stage: ProjectStage
    let health: ProjectHealth
    let progress: Double
    let referencesCount: Int
    let collaboratorsCount: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case reviewQuestion = "review_question"
        case stage
        case health
        case progress
        case referencesCount = "references_count"
        case collaboratorsCount = "collaborators_count"
        case updatedAt = "updated_at"
    }
}

extension ProjectSummary {
    init(detail: ProjectDetail) {
        self.id = detail.id
        self.title = detail.title
        self.reviewQuestion = detail.reviewQuestion
        self.stage = detail.stage
        self.health = detail.health
        self.progress = detail.progress
        self.referencesCount = detail.referencesCount
        self.collaboratorsCount = detail.collaboratorsCount
        self.updatedAt = detail.updatedAt
    }
}

struct ProjectDetail: Codable, Identifiable {
    let id: String
    let title: String
    let reviewQuestion: String
    let stage: ProjectStage
    let health: ProjectHealth
    let progress: Double
    let referencesCount: Int
    let collaboratorsCount: Int
    let updatedAt: Date
    let teamName: String
    let description: String?
    let population: String?
    let intervention: String?
    let comparator: String?
    let outcome: String?
    let studyDesign: String?
    let humanReviewPolicy: String?
    let aiAssistPolicy: String?
    let lead: UserSummary
    let members: [MemberSummary]
    let automations: [AutomationJobSummary]
    let nextActions: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case reviewQuestion = "review_question"
        case stage
        case health
        case progress
        case referencesCount = "references_count"
        case collaboratorsCount = "collaborators_count"
        case updatedAt = "updated_at"
        case teamName = "team_name"
        case description
        case population
        case intervention
        case comparator
        case outcome
        case studyDesign = "study_design"
        case humanReviewPolicy = "human_review_policy"
        case aiAssistPolicy = "ai_assist_policy"
        case lead
        case members
        case automations
        case nextActions = "next_actions"
    }
}

struct ProjectDraftMember: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var email: String = ""
    var role: MembershipRole
    var assignedStages: [ReviewProcessStage] = ReviewProcessStage.allCases
}

struct ProjectDraft {
    var title = ""
    var reviewQuestion = ""
    var teamName = ""
    var description = ""
    var population = ""
    var intervention = ""
    var comparator = ""
    var outcome = ""
    var studyDesign = ""
    var humanReviewPolicy = "Humans make the final decisions on inclusion, exclusion, extraction, and reporting."
    var aiAssistPolicy = "AI supports search drafting, summarization, screening suggestions, and drafting support under human supervision."
    var members: [ProjectDraftMember] = []

    init() {}

    init(project: ProjectDetail) {
        self.title = project.title
        self.reviewQuestion = project.reviewQuestion
        self.teamName = project.teamName
        self.description = project.description ?? ""
        self.population = project.population ?? ""
        self.intervention = project.intervention ?? ""
        self.comparator = project.comparator ?? ""
        self.outcome = project.outcome ?? ""
        self.studyDesign = project.studyDesign ?? ""
        self.humanReviewPolicy = project.humanReviewPolicy ?? "Humans make the final decisions on inclusion, exclusion, extraction, and reporting."
        self.aiAssistPolicy = project.aiAssistPolicy ?? "AI supports search drafting, summarization, screening suggestions, and drafting support under human supervision."
        self.members = project.members.map { member in
            ProjectDraftMember(
                id: member.id,
                name: member.name,
                email: member.email ?? "",
                role: member.role,
                assignedStages: member.assignedStages
            )
        }
    }
}

struct SearchConcept: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var category: String
    var term: String = ""
    var synonyms: [String] = []
}

struct DatabaseSearch: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var databaseName: String = ""
    var strategy: String = ""
}

struct ImportedReference: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var customID: String = ""
    var title: String = ""
    var authors: [String] = []
    var publicationYear: String = ""
    var abstractText: String = ""
    var doi: String = ""
    var url: String = ""
    var sourceFormat: String = ""
    var votes: [ScreeningVote] = []
    var finalDecision: ScreeningDecision = .unknown
    var pdfLocalPath: String? = nil
    var retrievalStatus: RetrievalStatus = .none
    var fullTextVotes: [ScreeningVote] = []
    var fullTextFinalDecision: ScreeningDecision = .unknown
    var fullTextReason: String = ""
    var extractionData: [String: String] = [:]
    var extractionExcerpts: [String: String] = [:]
    var qualityData: [String: QualityAssessmentValue] = [:]

    var formattedAuthors: String {
        if authors.isEmpty {
            return "No authors listed"
        }
        return authors.joined(separator: ", ")
    }

    var displayDate: String {
        publicationYear.isEmpty ? "Year unknown" : publicationYear
    }

    var cleanAbstract: String {
        abstractText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var pdfURL: URL? {
        guard let pdfLocalPath else { return nil }
        return URL(fileURLWithPath: pdfLocalPath)
    }

    var consensusStatus: ScreeningDecision {
        if finalDecision != .unknown {
            return finalDecision
        }

        let validVotes = votes.filter {
            $0.decision == .included || $0.decision == .excluded
        }
        if validVotes.isEmpty {
            return .unknown
        }

        let hasIncluded = validVotes.contains { $0.decision == .included }
        let hasExcluded = validVotes.contains { $0.decision == .excluded }
        if hasIncluded && hasExcluded {
            return .conflict
        }
        return hasIncluded ? .included : .excluded
    }

    var hasConflict: Bool {
        consensusStatus == .conflict
    }

    var fullTextConsensusStatus: ScreeningDecision {
        if fullTextFinalDecision != .unknown {
            return fullTextFinalDecision
        }

        let validVotes = fullTextVotes.filter {
            $0.decision == .included || $0.decision == .excluded
        }
        if validVotes.isEmpty {
            return .unknown
        }

        let hasIncluded = validVotes.contains { $0.decision == .included }
        let hasExcluded = validVotes.contains { $0.decision == .excluded }
        if hasIncluded && hasExcluded {
            return .conflict
        }
        return hasIncluded ? .included : .excluded
    }

    var hasFullTextConflict: Bool {
        fullTextConsensusStatus == .conflict
    }

    var humanVotes: [ScreeningVote] {
        votes.filter { !$0.isAI }
    }

    var aiVotes: [ScreeningVote] {
        votes.filter(\.isAI)
    }

    var fullTextHumanVotes: [ScreeningVote] {
        fullTextVotes.filter { !$0.isAI }
    }

    var fullTextAIVotes: [ScreeningVote] {
        fullTextVotes.filter(\.isAI)
    }

    var isEligibleForFullText: Bool {
        consensusStatus == .included
    }

    var isEligibleForExtraction: Bool {
        fullTextConsensusStatus == .included
    }

    var hasExtractionData: Bool {
        extractionData.contains { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasQualityAssessment: Bool {
        qualityData.contains { $0.value != .unclear }
    }
}

struct SearchWorkspace: Codable, Hashable {
    var searchConcepts: [SearchConcept]
    var databaseSearches: [DatabaseSearch]
    var importedReferences: [ImportedReference]
    var screeningMode: ScreeningMode
    var inclusionCriteria: [ScreeningCriterion]
    var exclusionCriteria: [ScreeningCriterion]
    var extractionFields: [ExtractionField]
    var qualityCriteria: [QualityCriterion]
    var variableSynthesis: [String: String]
    var reportTitleSection: String
    var reportKeywords: String
    var reportAbstract: String
    var reportIntroduction: String
    var reportMethods: String
    var reportResults: String
    var reportDiscussion: String
    var reportReferences: String
    var reportAppendices: String
    var reportCitationStyle: CitationStyle

    init(
        searchConcepts: [SearchConcept] = SearchWorkspace.defaultConcepts(),
        databaseSearches: [DatabaseSearch] = [DatabaseSearch(databaseName: "PubMed")],
        importedReferences: [ImportedReference] = [],
        screeningMode: ScreeningMode = .double,
        inclusionCriteria: [ScreeningCriterion] = SearchWorkspace.defaultInclusionCriteria(),
        exclusionCriteria: [ScreeningCriterion] = SearchWorkspace.defaultExclusionCriteria(),
        extractionFields: [ExtractionField] = SearchWorkspace.defaultExtractionFields(),
        qualityCriteria: [QualityCriterion] = SearchWorkspace.defaultQualityCriteria(),
        variableSynthesis: [String: String] = [:],
        reportTitleSection: String = "",
        reportKeywords: String = "",
        reportAbstract: String = "",
        reportIntroduction: String = "",
        reportMethods: String = "",
        reportResults: String = "",
        reportDiscussion: String = "",
        reportReferences: String = "",
        reportAppendices: String = "",
        reportCitationStyle: CitationStyle = .vancouver
    ) {
        self.searchConcepts = searchConcepts
        self.databaseSearches = databaseSearches
        self.importedReferences = importedReferences
        self.screeningMode = screeningMode
        self.inclusionCriteria = inclusionCriteria
        self.exclusionCriteria = exclusionCriteria
        self.extractionFields = extractionFields
        self.qualityCriteria = qualityCriteria
        self.variableSynthesis = variableSynthesis
        self.reportTitleSection = reportTitleSection
        self.reportKeywords = reportKeywords
        self.reportAbstract = reportAbstract
        self.reportIntroduction = reportIntroduction
        self.reportMethods = reportMethods
        self.reportResults = reportResults
        self.reportDiscussion = reportDiscussion
        self.reportReferences = reportReferences
        self.reportAppendices = reportAppendices
        self.reportCitationStyle = reportCitationStyle
    }

    init(project: ProjectDetail) {
        self.searchConcepts = SearchWorkspace.defaultConcepts(for: project)
        self.databaseSearches = [DatabaseSearch(databaseName: "PubMed")]
        self.importedReferences = []
        self.screeningMode = .double
        self.inclusionCriteria = SearchWorkspace.defaultInclusionCriteria()
        self.exclusionCriteria = SearchWorkspace.defaultExclusionCriteria()
        self.extractionFields = SearchWorkspace.defaultExtractionFields()
        self.qualityCriteria = SearchWorkspace.defaultQualityCriteria()
        self.variableSynthesis = [:]
        self.reportTitleSection = ""
        self.reportKeywords = ""
        self.reportAbstract = ""
        self.reportIntroduction = ""
        self.reportMethods = ""
        self.reportResults = ""
        self.reportDiscussion = ""
        self.reportReferences = ""
        self.reportAppendices = ""
        self.reportCitationStyle = .vancouver
    }

    var allKeywords: [String] {
        searchConcepts
            .flatMap { concept in [concept.term] + concept.synonyms }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasHumanDefinedStrategy: Bool {
        searchConcepts.contains { !$0.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || databaseSearches.contains {
                !$0.databaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !$0.strategy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    var screeningCounts: (pending: Int, included: Int, excluded: Int, conflicts: Int) {
        (
            importedReferences.filter { $0.consensusStatus == .unknown || $0.consensusStatus == .insufficientInfo }.count,
            importedReferences.filter { $0.consensusStatus == .included }.count,
            importedReferences.filter { $0.consensusStatus == .excluded }.count,
            importedReferences.filter(\.hasConflict).count
        )
    }

    var hasScreeningActivity: Bool {
        importedReferences.contains { !$0.votes.isEmpty || $0.finalDecision != .unknown }
    }

    var fullTextRetrievalCounts: (eligible: Int, attached: Int, missing: Int) {
        let eligibleReferences = importedReferences.filter(\.isEligibleForFullText)
        return (
            eligibleReferences.count,
            eligibleReferences.filter { $0.pdfURL != nil }.count,
            eligibleReferences.filter { $0.pdfURL == nil }.count
        )
    }

    var fullTextCounts: (pending: Int, included: Int, excluded: Int, conflicts: Int) {
        let eligibleReferences = importedReferences.filter(\.isEligibleForFullText)
        return (
            eligibleReferences.filter { $0.fullTextConsensusStatus == .unknown || $0.fullTextConsensusStatus == .insufficientInfo }.count,
            eligibleReferences.filter { $0.fullTextConsensusStatus == .included }.count,
            eligibleReferences.filter { $0.fullTextConsensusStatus == .excluded }.count,
            eligibleReferences.filter(\.hasFullTextConflict).count
        )
    }

    var hasFullTextActivity: Bool {
        importedReferences.contains {
            $0.pdfURL != nil || $0.retrievalStatus != .none || !$0.fullTextVotes.isEmpty || $0.fullTextFinalDecision != .unknown
        }
    }

    var eligibleForExtractionCount: Int {
        importedReferences.filter(\.isEligibleForExtraction).count
    }

    var extractionCompletionCounts: (eligible: Int, completed: Int, qaStarted: Int) {
        let eligibleReferences = importedReferences.filter(\.isEligibleForExtraction)
        return (
            eligibleReferences.count,
            eligibleReferences.filter(\.hasExtractionData).count,
            eligibleReferences.filter(\.hasQualityAssessment).count
        )
    }

    var hasExtractionActivity: Bool {
        importedReferences.contains { $0.hasExtractionData || $0.hasQualityAssessment }
    }

    var hasSynthesisActivity: Bool {
        variableSynthesis.contains { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasReportDraftActivity: Bool {
        [
            reportTitleSection,
            reportKeywords,
            reportAbstract,
            reportIntroduction,
            reportMethods,
            reportResults,
            reportDiscussion,
            reportReferences,
            reportAppendices
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var allFlatFields: [ExtractionField] {
        var flat: [ExtractionField] = []

        func traverse(_ fields: [ExtractionField]) {
            for field in fields {
                if !field.isSection {
                    flat.append(field)
                }
                traverse(field.children)
            }
        }

        traverse(extractionFields)
        return flat
    }

    var synthesizedFieldCount: Int {
        variableSynthesis.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var reportSectionCompletionCount: Int {
        [
            reportTitleSection,
            reportKeywords,
            reportAbstract,
            reportIntroduction,
            reportMethods,
            reportResults,
            reportDiscussion,
            reportReferences,
            reportAppendices
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .count
    }

    var includedReferencesForReporting: [ImportedReference] {
        importedReferences.filter(\.isEligibleForExtraction)
    }

    static func defaultConcepts() -> [SearchConcept] {
        [
            SearchConcept(category: "Population"),
            SearchConcept(category: "Intervention"),
            SearchConcept(category: "Comparator"),
            SearchConcept(category: "Outcome"),
            SearchConcept(category: "Study Design")
        ]
    }

    static func defaultConcepts(for project: ProjectDetail) -> [SearchConcept] {
        [
            SearchConcept(category: "Population", term: project.population ?? ""),
            SearchConcept(category: "Intervention", term: project.intervention ?? ""),
            SearchConcept(category: "Comparator", term: project.comparator ?? ""),
            SearchConcept(category: "Outcome", term: project.outcome ?? ""),
            SearchConcept(category: "Study Design", term: project.studyDesign ?? "")
        ]
    }

    static func defaultInclusionCriteria() -> [ScreeningCriterion] {
        [
            ScreeningCriterion(name: "Matches population", description: "The title or abstract aligns with the target population."),
            ScreeningCriterion(name: "Relevant intervention/exposure", description: "The intervention, exposure, or model appears relevant to the review question.")
        ]
    }

    static func defaultExclusionCriteria() -> [ScreeningCriterion] {
        [
            ScreeningCriterion(name: "Wrong study design", description: "The record clearly reports an ineligible study design."),
            ScreeningCriterion(name: "Out of scope", description: "The population, setting, or intervention is out of scope for this review.")
        ]
    }

    static func defaultExtractionFields() -> [ExtractionField] {
        [
            ExtractionField(
                name: "Study Characteristics",
                description: "Capture the basic design and setting details.",
                type: .section,
                children: [
                    ExtractionField(name: "Study year", description: "Publication year or study period.", type: .number),
                    ExtractionField(name: "Country", description: "Primary location or setting.", type: .text),
                    ExtractionField(name: "Study design", description: "Trial, cohort, qualitative study, etc.", type: .text)
                ]
            ),
            ExtractionField(
                name: "Participants",
                description: "Record who was studied and sample size details.",
                type: .section,
                children: [
                    ExtractionField(name: "Population", description: "Participants or target group.", type: .text),
                    ExtractionField(name: "Sample size", description: "Total number enrolled or analyzed.", type: .number)
                ]
            ),
            ExtractionField(
                name: "Outcomes",
                description: "Record the primary outcomes relevant to the review question.",
                type: .section,
                children: [
                    ExtractionField(name: "Primary outcome", description: "Main outcome result.", type: .text),
                    ExtractionField(name: "Effect estimate", description: "Key numerical result if reported.", type: .text)
                ]
            )
        ]
    }

    static func defaultQualityCriteria() -> [QualityCriterion] {
        [
            QualityCriterion(name: "Selection bias", description: "Was participant selection likely to bias results?"),
            QualityCriterion(name: "Measurement quality", description: "Were exposures and outcomes measured appropriately?"),
            QualityCriterion(name: "Completeness of reporting", description: "Does the report provide enough detail to trust the extracted data?")
        ]
    }
}

struct WorkspaceSyncMetadata: Codable, Hashable {
    var version: Int
    var updatedAt: Date
    var updatedBy: String?
    var editorName: String?
}

struct WorkspaceSyncNotice: Identifiable, Codable, Hashable {
    var id: String { projectID }
    let projectID: String
    let message: String
    let serverVersion: Int
    let serverUpdatedAt: Date
    let editorName: String?
    let localWorkspace: SearchWorkspace
    let serverWorkspace: SearchWorkspace
}

enum SearchSortOption: String, CaseIterable, Identifiable {
    case newest = "Newest first"
    case oldest = "Oldest first"
    case title = "Title A-Z"

    var id: String { rawValue }
}

enum ScreeningMode: String, Codable, CaseIterable, Identifiable {
    case single = "Single reviewer + AI"
    case double = "Two reviewers + AI"
    case aiAssisted = "AI assisted triage"

    var id: String { rawValue }
}

enum ScreeningDecision: String, Codable, CaseIterable, Identifiable {
    case unknown = "Pending"
    case included = "Included"
    case excluded = "Excluded"
    case conflict = "Conflict"
    case insufficientInfo = "Need Info"

    var id: String { rawValue }
}

enum RetrievalStatus: String, Codable, CaseIterable, Identifiable {
    case none = ""
    case searching = "Checking open access"
    case found = "PDF attached"
    case notFound = "No PDF found"
    case error = "Retrieval error"

    var id: String { rawValue }
}

extension ScreeningDecision {
    var color: String {
        switch self {
        case .included:
            return "green"
        case .excluded:
            return "red"
        case .conflict:
            return "orange"
        case .insufficientInfo:
            return "yellow"
        case .unknown:
            return "gray"
        }
    }
}

enum FieldType: String, Codable, CaseIterable, Identifiable {
    case section = "Section Header"
    case text = "Text"
    case number = "Number"

    var id: String { rawValue }
}

enum QualityAssessmentValue: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case high = "High"
    case unclear = "Unclear"

    var id: String { rawValue }
}

enum CitationStyle: String, Codable, CaseIterable, Identifiable {
    case vancouver = "Vancouver"
    case apa = "APA"
    case harvard = "Harvard"

    var id: String { rawValue }
}

enum CitationExportFormat: String, CaseIterable, Identifiable {
    case ris = "RIS"
    case bibTeX = "BibTeX"

    var id: String { rawValue }

    var filenameExtension: String {
        switch self {
        case .ris:
            return "ris"
        case .bibTeX:
            return "bib"
        }
    }
}

struct ScreeningCriterion: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var description: String
}

struct ExtractionField: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var description: String = ""
    var type: FieldType
    var children: [ExtractionField] = []

    var isSection: Bool {
        type == .section
    }
}

struct QualityCriterion: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var description: String
}

struct ScreeningVote: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var screenerName: String
    var decision: ScreeningDecision
    var reason: String
    var criterionUsed: String
    var isAI: Bool
    var timestamp: Date = Date()
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct SessionBootstrap {
    let user: UserSummary
    let projects: [ProjectSummary]
}
