import Foundation

@MainActor
final class APIClient {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession
    private var accessToken: String?

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func login(email: String, password: String) async throws -> SessionBootstrap {
        let request = LoginRequest(email: email, password: password)
        let token = try await post(path: "/v1/auth/login", body: request, responseType: AuthToken.self)
        accessToken = token.accessToken
        let user: UserSummary = try await get(path: "/v1/auth/me", responseType: UserSummary.self)
        let projects: [ProjectSummary] = try await get(path: "/v1/projects", responseType: [ProjectSummary].self)
        return SessionBootstrap(user: user, projects: projects)
    }

    func clearSession() {
        accessToken = nil
    }

    func fetchProjects() async throws -> [ProjectSummary] {
        try await get(path: "/v1/projects", responseType: [ProjectSummary].self)
    }

    func fetchProject(id: String) async throws -> ProjectDetail {
        do {
            return try await get(path: "/v1/projects/\(id)", responseType: ProjectDetail.self)
        } catch {
            return try DemoData.projectDetail(id: id)
        }
    }

    func updateProject(id: String, draft: ProjectDraft) async throws -> ProjectDetail {
        let request = ProjectUpdateRequest(draft: draft)
        return try await put(path: "/v1/projects/\(id)", body: request, responseType: ProjectDetail.self)
    }

    func fetchProjectWorkspace(projectID: String) async throws -> WorkspaceLoadResult? {
        let envelope = try await get(
            path: "/v1/projects/\(projectID)/workspace",
            responseType: WorkspaceEnvelope.self
        )
        return WorkspaceLoadResult(
            workspace: try decodeWorkspace(from: envelope.payload),
            metadata: WorkspaceSyncMetadata(
                version: envelope.version,
                updatedAt: envelope.updatedAt,
                updatedBy: envelope.updatedBy,
                editorName: envelope.editorName
            )
        )
    }

    func syncProjectWorkspace(
        projectID: String,
        workspace: SearchWorkspace,
        stage: ProjectStage,
        progress: Double,
        referencesCount: Int,
        baseVersion: Int?,
        updatedBy: String?,
        editorName: String?
    ) async throws -> WorkspaceSyncMetadata {
        let envelope = WorkspaceEnvelope(
            projectID: projectID,
            updatedAt: Date(),
            stage: stage,
            progress: progress,
            referencesCount: referencesCount,
            version: max(1, baseVersion ?? 1),
            baseVersion: baseVersion,
            updatedBy: updatedBy,
            editorName: editorName,
            payload: try encodeWorkspace(workspace)
        )

        let savedEnvelope = try await put(
            path: "/v1/projects/\(projectID)/workspace",
            body: envelope,
            responseType: WorkspaceEnvelope.self
        )
        return WorkspaceSyncMetadata(
            version: savedEnvelope.version,
            updatedAt: savedEnvelope.updatedAt,
            updatedBy: savedEnvelope.updatedBy,
            editorName: savedEnvelope.editorName
        )
    }

    func fetchWorkspaceConflicts(projectID: String) async throws -> [WorkspaceConflictNotice] {
        try await get(path: "/v1/projects/\(projectID)/workspace/conflicts", responseType: [WorkspaceConflictNotice].self)
    }

    private func get<T: Decodable>(path: String, responseType: T.Type) async throws -> T {
        let url = AppConfig.apiBaseURL.appending(path: path)
        do {
            let request = authorizedRequest(url: url)
            let (data, response) = try await session.data(for: request)
            try validate(response: response)
            return try decoder.decode(T.self, from: data)
        } catch {
            return try DemoData.decode(responseType)
        }
    }

    private func post<T: Encodable, R: Decodable>(path: String, body: T, responseType: R.Type) async throws -> R {
        let url = AppConfig.apiBaseURL.appending(path: path)
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response)
            return try decoder.decode(R.self, from: data)
        } catch {
            return try DemoData.decode(responseType)
        }
    }

    private func put<T: Encodable, R: Decodable>(path: String, body: T, responseType: R.Type) async throws -> R {
        let url = AppConfig.apiBaseURL.appending(path: path)
        var request = authorizedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        do {
            try validate(response: response)
        } catch {
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 409 {
                let conflict = try decoder.decode(ConflictEnvelope.self, from: data)
                throw APIClientError.workspaceConflict(conflict)
            }
            throw error
        }
        return try decoder.decode(R.self, from: data)
    }

    private func encodeWorkspace(_ workspace: SearchWorkspace) throws -> [String: JSONValue] {
        let data = try encoder.encode(workspace)
        return try decoder.decode([String: JSONValue].self, from: data)
    }

    private func decodeWorkspace(from payload: [String: JSONValue]) throws -> SearchWorkspace {
        let data = try encoder.encode(payload)
        return try decoder.decode(SearchWorkspace.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func decodeWorkspaceEnvelope(_ envelope: WorkspaceEnvelope) throws -> SearchWorkspace {
        try decodeWorkspace(from: envelope.payload)
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let accessToken {
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

struct WorkspaceLoadResult {
    let workspace: SearchWorkspace
    let metadata: WorkspaceSyncMetadata
}

private struct ProjectUpdateRequest: Encodable {
    let title: String
    let reviewQuestion: String
    let teamName: String
    let description: String
    let population: String
    let intervention: String
    let comparator: String
    let outcome: String
    let studyDesign: String
    let humanReviewPolicy: String
    let aiAssistPolicy: String
    let members: [ProjectMemberRequest]

    init(draft: ProjectDraft) {
        self.title = draft.title
        self.reviewQuestion = draft.reviewQuestion
        self.teamName = draft.teamName
        self.description = draft.description
        self.population = draft.population
        self.intervention = draft.intervention
        self.comparator = draft.comparator
        self.outcome = draft.outcome
        self.studyDesign = draft.studyDesign
        self.humanReviewPolicy = draft.humanReviewPolicy
        self.aiAssistPolicy = draft.aiAssistPolicy
        self.members = draft.members.map { ProjectMemberRequest(member: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case reviewQuestion = "review_question"
        case teamName = "team_name"
        case description
        case population
        case intervention
        case comparator
        case outcome
        case studyDesign = "study_design"
        case humanReviewPolicy = "human_review_policy"
        case aiAssistPolicy = "ai_assist_policy"
        case members
    }
}

private struct ProjectMemberRequest: Encodable {
    let id: String
    let name: String
    let email: String?
    let role: MembershipRole
    let assignedStages: [ReviewProcessStage]

    init(member: ProjectDraftMember) {
        self.id = member.id
        self.name = member.name
        self.email = member.email.isEmpty ? nil : member.email
        self.role = member.role
        self.assignedStages = member.role == .owner ? ReviewProcessStage.allCases : member.assignedStages
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case assignedStages = "assigned_stages"
    }
}

struct WorkspaceConflictNotice: Codable, Identifiable {
    let id: String
    let projectID: String
    let createdAt: Date
    let clientBaseVersion: Int?
    let serverVersion: Int
    let updatedBy: String?
    let editorName: String?
    let summary: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case createdAt = "created_at"
        case clientBaseVersion = "client_base_version"
        case serverVersion = "server_version"
        case updatedBy = "updated_by"
        case editorName = "editor_name"
        case summary
    }
}

enum APIClientError: LocalizedError {
    case workspaceConflict(ConflictEnvelope)

    var errorDescription: String? {
        switch self {
        case .workspaceConflict(let envelope):
            return envelope.message
        }
    }
}

struct WorkspaceEnvelope: Codable {
    let projectID: String
    let updatedAt: Date
    let stage: ProjectStage
    let progress: Double
    let referencesCount: Int
    let version: Int
    let baseVersion: Int?
    let updatedBy: String?
    let editorName: String?
    let payload: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case updatedAt = "updated_at"
        case stage
        case progress
        case referencesCount = "references_count"
        case version
        case baseVersion = "base_version"
        case updatedBy = "updated_by"
        case editorName = "editor_name"
        case payload
    }
}

struct ConflictEnvelope: Codable {
    let message: String
    let latestSnapshot: WorkspaceEnvelope
    let conflict: WorkspaceConflictNotice

    enum CodingKeys: String, CodingKey {
        case message
        case latestSnapshot = "latest_snapshot"
        case conflict
    }
}

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

private enum DemoData {
    static func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if type == AuthToken.self {
            return try decoder.decode(T.self, from: Data(authToken.utf8))
        }
        if type == UserSummary.self {
            return try decoder.decode(T.self, from: Data(user.utf8))
        }
        if type == [ProjectSummary].self {
            return try decoder.decode(T.self, from: Data(projects.utf8))
        }
        throw URLError(.cannotDecodeContentData)
    }

    static func projectDetail(id: String) throws -> ProjectDetail {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = switch id {
        case "proj_hiv": projectDetailHIV
        default: projectDetailMalaria
        }

        return try decoder.decode(ProjectDetail.self, from: Data(payload.utf8))
    }

    private static let authToken = """
    {
      "access_token": "demo-token",
      "token_type": "bearer",
      "expires_in": 3600
    }
    """

    private static let user = """
    {
      "id": "user_demo",
      "name": "Pastan Lusiba",
      "email": "pastan@example.com",
      "title": "Lead Reviewer"
    }
    """

    private static let projects = """
    [
      {
        "id": "proj_malaria",
        "title": "Malaria Prevention in Pregnancy",
        "review_question": "Which interventions reduce malaria-related maternal outcomes in East Africa?",
        "stage": "screening",
        "health": "on_track",
        "progress": 0.42,
        "references_count": 284,
        "collaborators_count": 4,
        "updated_at": "2026-03-17T10:00:00Z"
      },
      {
        "id": "proj_hiv",
        "title": "Community HIV Testing Models",
        "review_question": "Which delivery models improve HIV testing uptake in underserved communities?",
        "stage": "full_text",
        "health": "at_risk",
        "progress": 0.63,
        "references_count": 143,
        "collaborators_count": 3,
        "updated_at": "2026-03-16T15:00:00Z"
      }
    ]
    """

    private static let projectDetailMalaria = """
    {
      "id": "proj_malaria",
      "title": "Malaria Prevention in Pregnancy",
      "review_question": "Which interventions reduce malaria-related maternal outcomes in East Africa?",
      "stage": "screening",
      "health": "on_track",
      "progress": 0.42,
      "references_count": 284,
      "collaborators_count": 4,
      "updated_at": "2026-03-17T10:00:00Z",
      "team_name": "Maternal Health Lab",
      "lead": {
        "id": "user_demo",
        "name": "Pastan Lusiba",
        "email": "pastan@example.com",
        "title": "Lead Reviewer"
      },
      "members": [
        { "id": "user_demo", "name": "Pastan Lusiba", "role": "owner" },
        { "id": "member_2", "name": "Grace Nampiima", "role": "editor" },
        { "id": "member_3", "name": "Daniel Ocen", "role": "reviewer" },
        { "id": "member_4", "name": "Sarah Kigozi", "role": "viewer" }
      ],
      "automations": [
        {
          "id": "job_screening_1",
          "title": "Title and abstract screening batch",
          "status": "running",
          "provider": "openai",
          "updated_at": "2026-03-17T11:46:00Z"
        },
        {
          "id": "job_summary_1",
          "title": "Weekly synthesis summary",
          "status": "queued",
          "provider": "openai",
          "updated_at": "2026-03-17T11:57:00Z"
        }
      ],
      "next_actions": [
        "Resolve 12 title and abstract conflicts",
        "Upload 19 missing full-text PDFs",
        "Finalize extraction form fields"
      ]
    }
    """

    private static let projectDetailHIV = """
    {
      "id": "proj_hiv",
      "title": "Community HIV Testing Models",
      "review_question": "Which delivery models improve HIV testing uptake in underserved communities?",
      "stage": "full_text",
      "health": "at_risk",
      "progress": 0.63,
      "references_count": 143,
      "collaborators_count": 3,
      "updated_at": "2026-03-16T15:00:00Z",
      "team_name": "Evidence to Action",
      "lead": {
        "id": "user_demo",
        "name": "Pastan Lusiba",
        "email": "pastan@example.com",
        "title": "Lead Reviewer"
      },
      "members": [
        { "id": "user_demo", "name": "Pastan Lusiba", "role": "owner" },
        { "id": "member_5", "name": "Esther Ayo", "role": "editor" },
        { "id": "member_6", "name": "Mark Ssenfuka", "role": "reviewer" }
      ],
      "automations": [
        {
          "id": "job_ft_1",
          "title": "Full-text inclusion suggestion run",
          "status": "completed",
          "provider": "openai",
          "updated_at": "2026-03-17T06:30:00Z"
        }
      ],
      "next_actions": [
        "Review excluded full-text rationale",
        "Assign missing quality assessments"
      ]
    }
    """
}
