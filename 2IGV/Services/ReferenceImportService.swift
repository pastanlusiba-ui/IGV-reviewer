import Foundation
import UniformTypeIdentifiers

extension UTType {
    static var ris: UTType { UTType(filenameExtension: "ris") ?? .plainText }
    static var bibtex: UTType { UTType(filenameExtension: "bib") ?? .plainText }
    static var endnote: UTType { UTType(filenameExtension: "enw") ?? .plainText }
    static var nbib: UTType { UTType(filenameExtension: "nbib") ?? .plainText }
}

enum ReferenceImportService {
    static func importReferences(from url: URL, startingAt startIndex: Int) throws -> [ImportedReference] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let pathExtension = url.pathExtension.lowercased()

        let parsedRecords: [ImportedReference]
        switch pathExtension {
        case "bib":
            parsedRecords = parseBibTeX(content)
        case "ris", "nbib", "enw":
            parsedRecords = parseTaggedRecords(content)
        default:
            let tagged = parseTaggedRecords(content)
            parsedRecords = tagged.isEmpty ? parsePlainText(content) : tagged
        }

        var nextIndex = startIndex
        return parsedRecords.map { record in
            var numbered = record
            numbered.customID = String(nextIndex)
            nextIndex += 1
            return numbered
        }
    }

    private static func parseTaggedRecords(_ content: String) -> [ImportedReference] {
        var normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let tags = ["TI", "T1", "AB", "N2", "PY", "Y1", "DP", "AU", "FAU", "A1", "DO", "DI", "UR", "L2"]
        for tag in tags {
            normalized = normalized.replacingOccurrences(of: " \(tag) - ", with: "\n\(tag) - ")
            normalized = normalized.replacingOccurrences(of: " \(tag)- ", with: "\n\(tag)- ")
            normalized = normalized.replacingOccurrences(of: " \(tag)  - ", with: "\n\(tag)  - ")
        }

        let candidateChunks = normalized
            .components(separatedBy: "\nER  -")
            .flatMap { $0.components(separatedBy: "\nPMID-") }

        var records: [ImportedReference] = []
        for chunk in candidateChunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let title = extractFirstField(from: trimmed, tags: ["TI", "T1"])
            let abstract = extractFirstField(from: trimmed, tags: ["AB", "N2"])
            let year = extractFirstField(from: trimmed, tags: ["PY", "Y1", "DP"])
            let doi = extractFirstField(from: trimmed, tags: ["DO", "DI"])
            let url = extractFirstField(from: trimmed, tags: ["UR", "L2"])
            let authors = extractAllFields(from: trimmed, tags: ["FAU", "AU", "A1"])

            if title.isEmpty && abstract.isEmpty {
                continue
            }

            records.append(
                ImportedReference(
                    title: title,
                    authors: authors,
                    publicationYear: normalizedYear(from: year),
                    abstractText: abstract,
                    doi: doi,
                    url: url,
                    sourceFormat: "Tagged import"
                )
            )
        }

        return records
    }

    private static func parseBibTeX(_ content: String) -> [ImportedReference] {
        let entries = content
            .components(separatedBy: "@")
            .map { "@" + $0 }
            .filter { $0.starts(with: "@") }

        return entries.compactMap { entry in
            let title = extractBibField("title", from: entry)
            let abstract = extractBibField("abstract", from: entry)
            let authorsField = extractBibField("author", from: entry)
            let year = extractBibField("year", from: entry)
            let doi = extractBibField("doi", from: entry)
            let url = extractBibField("url", from: entry)

            guard !title.isEmpty || !abstract.isEmpty else {
                return nil
            }

            let authors = authorsField
                .components(separatedBy: " and ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return ImportedReference(
                title: title,
                authors: authors,
                publicationYear: normalizedYear(from: year),
                abstractText: abstract,
                doi: doi,
                url: url,
                sourceFormat: "BibTeX"
            )
        }
    }

    private static func parsePlainText(_ content: String) -> [ImportedReference] {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return []
        }

        return [
            ImportedReference(
                title: firstLine,
                authors: [],
                publicationYear: "",
                abstractText: lines.dropFirst().joined(separator: "\n"),
                doi: "",
                url: "",
                sourceFormat: "Plain text"
            )
        ]
    }

    private static func extractFirstField(from text: String, tags: [String]) -> String {
        for tag in tags {
            let pattern = "\(tag)\\s*-\\s*(.*?)(?=\\n[A-Z0-9]{2,4}\\s*-|$)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let captureRange = Range(match.range(at: 1), in: text) {
                return text[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func extractAllFields(from text: String, tags: [String]) -> [String] {
        let groupedTags = tags.joined(separator: "|")
        let pattern = "(?:\(groupedTags))\\s*-\\s*(.*?)(?=\\n[A-Z0-9]{2,4}\\s*-|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        var results: [String] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return
            }
            let value = text[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                results.append(value)
            }
        }
        return results
    }

    private static func extractBibField(_ key: String, from entry: String) -> String {
        let patterns = [
            "\(key)\\s*=\\s*\\{(.*?)\\}",
            "\(key)\\s*=\\s*\"(.*?)\""
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }
            let range = NSRange(entry.startIndex..., in: entry)
            if let match = regex.firstMatch(in: entry, options: [], range: range),
               let captureRange = Range(match.range(at: 1), in: entry) {
                return entry[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }

    private static func normalizedYear(from rawValue: String) -> String {
        let digits = rawValue.filter(\.isNumber)
        return digits.count >= 4 ? String(digits.prefix(4)) : rawValue
    }
}
