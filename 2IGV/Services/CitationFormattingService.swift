import Foundation

enum CitationFormattingService {
    nonisolated static func bibliography(for references: [ImportedReference], style: CitationStyle) -> String {
        references.enumerated().map { index, reference in
            formattedCitation(for: reference, style: style, index: index + 1)
        }
        .joined(separator: "\n\n")
    }

    nonisolated static func formattedCitation(for reference: ImportedReference, style: CitationStyle, index: Int? = nil) -> String {
        let authors = formattedAuthors(for: reference, style: style)
        let title = reference.title.isEmpty ? "Untitled study" : reference.title
        let year = reference.publicationYear.isEmpty ? "n.d." : reference.publicationYear
        let doiPart = reference.doi.isEmpty ? "" : " doi:\(reference.doi)"
        let urlPart = reference.url.isEmpty ? "" : " Available at: \(reference.url)"

        switch style {
        case .vancouver:
            let prefix = index.map { "\($0). " } ?? ""
            return "\(prefix)\(authors). \(title). \(year).\(doiPart)\(urlPart)"
        case .apa:
            return "\(authors) (\(year)). \(title).\(doiPart)\(urlPart)"
        case .harvard:
            return "\(authors) \(year), \(title).\(doiPart)\(urlPart)"
        }
    }

    nonisolated static func inTextCitation(for reference: ImportedReference, style: CitationStyle, index: Int? = nil) -> String {
        let firstAuthor = reference.authors.first?.components(separatedBy: " ").last ?? "Study"
        let year = reference.publicationYear.isEmpty ? "n.d." : reference.publicationYear

        switch style {
        case .vancouver:
            if let index {
                return "[\(index)]"
            }
            return "[ref]"
        case .apa:
            return "(\(firstAuthor), \(year))"
        case .harvard:
            return "(\(firstAuthor) \(year))"
        }
    }

    nonisolated static func ris(for references: [ImportedReference]) -> String {
        references.map { reference in
            let year = reference.publicationYear.isEmpty ? "n.d." : reference.publicationYear
            let title = reference.title.isEmpty ? "Untitled study" : reference.title

            var lines = [
                "TY  - JOUR",
                "TI  - \(title)",
                "PY  - \(year)"
            ]
            reference.authors.forEach { lines.append("AU  - \(normalizeAuthorName($0))") }
            if !reference.abstractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("AB  - \(reference.abstractText.replacingOccurrences(of: "\n", with: " "))")
            }
            if !reference.doi.isEmpty {
                lines.append("DO  - \(reference.doi)")
            }
            if !reference.url.isEmpty {
                lines.append("UR  - \(reference.url)")
            }
            lines.append("ER  -")
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    nonisolated static func bibTeX(for references: [ImportedReference]) -> String {
        references.enumerated().map { index, reference in
            let keyRoot = (reference.authors.first?.components(separatedBy: " ").last ?? "study")
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
            let year = reference.publicationYear.isEmpty ? "nd" : reference.publicationYear
            let citationKey = "\(keyRoot)\(year)\(index + 1)"
            let authorList = reference.authors.isEmpty
                ? "Unknown author"
                : reference.authors.map(normalizeAuthorName).joined(separator: " and ")

            var fields = [
                "  author = {\(escapeBibTeX(authorList))}",
                "  title = {\(escapeBibTeX(reference.title.isEmpty ? "Untitled study" : reference.title))}",
                "  year = {\(escapeBibTeX(year))}"
            ]
            if !reference.doi.isEmpty {
                fields.append("  doi = {\(escapeBibTeX(reference.doi))}")
            }
            if !reference.url.isEmpty {
                fields.append("  url = {\(escapeBibTeX(reference.url))}")
            }

            return "@article{\(citationKey),\n\(fields.joined(separator: ",\n"))\n}"
        }
        .joined(separator: "\n\n")
    }

    nonisolated private static func formattedAuthors(for reference: ImportedReference, style: CitationStyle) -> String {
        guard !reference.authors.isEmpty else { return "Unknown author" }

        switch style {
        case .vancouver:
            return reference.authors.prefix(6).map(vancouverAuthorName).joined(separator: ", ")
        case .apa, .harvard:
            if reference.authors.count == 1 {
                return normalizeAuthorName(reference.authors[0])
            }
            if reference.authors.count == 2 {
                return "\(normalizeAuthorName(reference.authors[0])) & \(normalizeAuthorName(reference.authors[1]))"
            }
            return "\(normalizeAuthorName(reference.authors[0])) et al."
        }
    }

    nonisolated private static func normalizeAuthorName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown author" }
        if trimmed.contains(",") {
            return trimmed
        }
        let parts = trimmed.split(separator: " ").map(String.init)
        guard let last = parts.last, parts.count > 1 else { return trimmed }
        let given = parts.dropLast().map { "\($0.prefix(1))." }.joined(separator: " ")
        return "\(last), \(given)"
    }

    nonisolated private static func vancouverAuthorName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown author" }
        let normalized = normalizeAuthorName(trimmed)
        let parts = normalized.components(separatedBy: ", ")
        guard parts.count == 2 else { return normalized }
        return "\(parts[0]) \(parts[1].replacingOccurrences(of: " ", with: ""))"
    }

    nonisolated private static func escapeBibTeX(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
    }
}
