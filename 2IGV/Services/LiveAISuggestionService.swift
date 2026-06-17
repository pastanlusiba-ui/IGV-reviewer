import Foundation
import PDFKit

enum LiveAISuggestionService {
    static func assistText(
        taskPrompt: String,
        sourceMaterial: String,
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> String? {
        let liveConnections = connections.filter { $0.mode == .ownAPIKey && !(apiKeyLookup($0) ?? "").isEmpty }

        for connection in liveConnections {
            guard let apiKey = apiKeyLookup(connection), !apiKey.isEmpty else {
                continue
            }

            do {
                return try await providerResponseText(
                    for: connection.provider,
                    apiKey: apiKey,
                    systemPrompt: "You help draft systematic review workspace text. Return plain text only.",
                    userPrompt: "\(taskPrompt)\n\nSource material:\n\(sourceMaterial)"
                )
            } catch {
                continue
            }
        }

        return nil
    }

    static func testConnection(
        connection: AIConnection,
        apiKeyLookup: (AIConnection) -> String?
    ) async -> ProviderConnectionTestResult {
        guard connection.mode == .ownAPIKey else {
            return ProviderConnectionTestResult(
                isSuccess: false,
                message: "Managed/app-hosted access is not testable locally yet. That path will be verified when backend-managed credits are added."
            )
        }

        guard let apiKey = apiKeyLookup(connection), !apiKey.isEmpty else {
            return ProviderConnectionTestResult(
                isSuccess: false,
                message: "No API key is stored for this connection."
            )
        }

        do {
            let text = try await providerResponseText(
                for: connection.provider,
                apiKey: apiKey,
                systemPrompt: "Reply with a short JSON object confirming connectivity.",
                userPrompt: #"Return JSON only: {"decision":"included","criterion":"connection test","reason":"connection ok"}"#
            )
            _ = try parseSuggestion(from: text)
            return ProviderConnectionTestResult(
                isSuccess: true,
                message: "Connection succeeded."
            )
        } catch {
            return ProviderConnectionTestResult(
                isSuccess: false,
                message: "Connection failed. Check the API key, billing state, provider model access, or network availability."
            )
        }
    }

    static func screeningSuggestions(
        for reference: ImportedReference,
        inclusionCriteria: [ScreeningCriterion],
        exclusionCriteria: [ScreeningCriterion],
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> [ScreeningVote] {
        let systemPrompt = """
        You assist with systematic review title and abstract screening.
        Your output is only a cautious suggestion for a human reviewer.
        If the evidence is ambiguous or incomplete, prefer insufficient_info.
        Return only valid JSON matching:
        {"decision":"included|excluded|insufficient_info","criterion":"short label","reason":"one or two sentences"}
        """

        let userPrompt = """
        Review title: \(reference.title)
        Authors: \(reference.formattedAuthors)
        Publication year: \(reference.publicationYear)
        DOI: \(reference.doi)

        Inclusion criteria:
        \(criteriaText(inclusionCriteria))

        Exclusion criteria:
        \(criteriaText(exclusionCriteria))

        Abstract:
        \(reference.cleanAbstract.isEmpty ? "No abstract available." : reference.cleanAbstract)
        """

        return await requestVotes(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        )
    }

    static func fullTextSuggestions(
        for reference: ImportedReference,
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> [ScreeningVote] {
        let pdfExcerpt = extractPDFExcerpt(from: reference.pdfURL)
        let systemPrompt = """
        You assist with systematic review full-text screening.
        Your output is only a cautious suggestion for a human reviewer.
        If the paper is missing, incomplete, or too ambiguous, prefer insufficient_info.
        Return only valid JSON matching:
        {"decision":"included|excluded|insufficient_info","criterion":"short label","reason":"one or two sentences"}
        """

        let userPrompt = """
        Review title: \(reference.title)
        Authors: \(reference.formattedAuthors)
        Publication year: \(reference.publicationYear)
        DOI: \(reference.doi)

        Abstract:
        \(reference.cleanAbstract.isEmpty ? "No abstract available." : reference.cleanAbstract)

        PDF status: \(reference.pdfURL == nil ? "No PDF attached." : "PDF attached.")

        PDF excerpt:
        \(pdfExcerpt.isEmpty ? "No PDF text could be extracted." : pdfExcerpt)
        """

        return await requestVotes(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            connections: connections,
            apiKeyLookup: apiKeyLookup
        )
    }

    private static func requestVotes(
        systemPrompt: String,
        userPrompt: String,
        connections: [AIConnection],
        apiKeyLookup: (AIConnection) -> String?
    ) async -> [ScreeningVote] {
        var votes: [ScreeningVote] = []
        let liveConnections = connections.filter { $0.mode == .ownAPIKey && !(apiKeyLookup($0) ?? "").isEmpty }

        for connection in liveConnections.prefix(2) {
            guard let apiKey = apiKeyLookup(connection), !apiKey.isEmpty else {
                continue
            }

            do {
                let responseText = try await providerResponseText(
                    for: connection.provider,
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                )
                let parsed = try parseSuggestion(from: responseText)
                votes.append(
                    ScreeningVote(
                        screenerName: connection.label,
                        decision: parsed.decision,
                        reason: parsed.reason,
                        criterionUsed: parsed.criterion,
                        isAI: true
                    )
                )
            } catch {
                continue
            }
        }

        return votes
    }

    private static func providerResponseText(
        for provider: AIProvider,
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        switch provider {
        case .openAI:
            return try await openAIResponseText(apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .gemini:
            return try await geminiResponseText(apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .perplexity:
            return try await perplexityResponseText(apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .deepSeek:
            return try await deepSeekResponseText(apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt)
        }
    }

    private static func openAIResponseText(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        let body: [String: Any] = [
            "model": "gpt-5",
            "input": [
                [
                    "role": "system",
                    "content": [["type": "input_text", "text": systemPrompt]]
                ],
                [
                    "role": "user",
                    "content": [["type": "input_text", "text": userPrompt]]
                ]
            ]
        ]

        let data = try await sendJSONRequest(
            url: url,
            apiKey: apiKey,
            headers: [:],
            body: body
        )

        let object = try jsonObject(from: data)
        if let outputText = object["output_text"] as? String, !outputText.isEmpty {
            return outputText
        }
        if let output = object["output"] as? [[String: Any]] {
            for item in output {
                guard let content = item["content"] as? [[String: Any]] else { continue }
                for part in content {
                    if let text = part["text"] as? String, !text.isEmpty {
                        return text
                    }
                    if let textDict = part["text"] as? [String: Any],
                       let text = textDict["value"] as? String,
                       !text.isEmpty {
                        return text
                    }
                }
            }
        }
        throw URLError(.cannotParseResponse)
    }

    private static func geminiResponseText(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "decision": [
                    "type": "string",
                    "enum": ["included", "excluded", "insufficient_info"]
                ],
                "criterion": ["type": "string"],
                "reason": ["type": "string"]
            ],
            "required": ["decision", "criterion", "reason"]
        ]
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemPrompt)\n\n\(userPrompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]

        let data = try await sendJSONRequest(
            url: url,
            apiKey: apiKey,
            headers: ["x-goog-api-key": apiKey],
            body: body
        )

        let object = try jsonObject(from: data)
        if let candidates = object["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String,
           !text.isEmpty {
            return text
        }
        throw URLError(.cannotParseResponse)
    }

    private static func perplexityResponseText(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let url = URL(string: "https://api.perplexity.ai/chat/completions")!
        let body: [String: Any] = [
            "model": "sonar-pro",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        let data = try await sendJSONRequest(
            url: url,
            apiKey: apiKey,
            headers: [:],
            body: body
        )

        return try openAICompatibleContent(from: data)
    }

    private static func deepSeekResponseText(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let url = URL(string: "https://api.deepseek.com/chat/completions")!
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false
        ]

        let data = try await sendJSONRequest(
            url: url,
            apiKey: apiKey,
            headers: [:],
            body: body
        )

        return try openAICompatibleContent(from: data)
    }

    private static func sendJSONRequest(
        url: URL,
        apiKey: String,
        headers: [String: String],
        body: [String: Any]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if headers["x-goog-api-key"] == nil {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func openAICompatibleContent(from data: Data) throws -> String {
        let object = try jsonObject(from: data)
        guard let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return content
    }

    private static func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return object
    }

    private static func parseSuggestion(from rawText: String) throws -> ParsedSuggestion {
        let sanitized = sanitizeJSON(rawText)
        guard let data = sanitized.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        let suggestion = try JSONDecoder().decode(ParsedSuggestionPayload.self, from: data)
        return ParsedSuggestion(
            decision: normalizeDecision(suggestion.decision),
            criterion: suggestion.criterion.trimmingCharacters(in: .whitespacesAndNewlines),
            reason: suggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func sanitizeJSON(_ rawText: String) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let withoutFence = trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            return withoutFence.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func normalizeDecision(_ rawDecision: String) -> ScreeningDecision {
        switch rawDecision.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "included", "include":
            return .included
        case "excluded", "exclude":
            return .excluded
        case "insufficient_info", "insufficientinfo", "need_info", "need info", "unclear":
            return .insufficientInfo
        default:
            return .insufficientInfo
        }
    }

    private static func criteriaText(_ criteria: [ScreeningCriterion]) -> String {
        if criteria.isEmpty {
            return "No criteria provided."
        }
        return criteria.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
    }

    private static func extractPDFExcerpt(from url: URL?) -> String {
        guard let url, let document = PDFDocument(url: url) else {
            return ""
        }

        var text = ""
        let pageLimit = min(document.pageCount, 8)
        for pageIndex in 0 ..< pageLimit {
            if let pageText = document.page(at: pageIndex)?.string {
                text += pageText + "\n"
            }
            if text.count > 12000 {
                break
            }
        }

        return String(text.prefix(12000)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ProviderConnectionTestResult {
    let isSuccess: Bool
    let message: String
}

private struct ParsedSuggestion {
    let decision: ScreeningDecision
    let criterion: String
    let reason: String
}

private struct ParsedSuggestionPayload: Decodable {
    let decision: String
    let criterion: String
    let reason: String
}
