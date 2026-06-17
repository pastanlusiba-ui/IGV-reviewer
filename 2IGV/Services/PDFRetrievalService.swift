import Foundation

private struct UnpaywallResponse: Codable {
    let bestOALocation: UnpaywallLocation?

    enum CodingKeys: String, CodingKey {
        case bestOALocation = "best_oa_location"
    }
}

private struct UnpaywallLocation: Codable {
    let pdfURL: String?

    enum CodingKeys: String, CodingKey {
        case pdfURL = "url_for_pdf"
    }
}

@MainActor
enum PDFRetrievalService {
    static func attemptRetrieval(
        for reference: ImportedReference,
        store: FullTextDocumentStore? = nil
    ) async -> (localURL: URL?, success: Bool, status: RetrievalStatus) {
        let store = store ?? FullTextDocumentStore()
        guard !reference.doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, false, .notFound)
        }

        let cleanDOI = reference.doi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let metadataURL = URL(string: "https://api.unpaywall.org/v2/\(cleanDOI)?email=guest@example.com") else {
            return (nil, false, .error)
        }

        do {
            let (metadataData, _) = try await URLSession.shared.data(from: metadataURL)
            let metadata = try JSONDecoder().decode(UnpaywallResponse.self, from: metadataData)
            guard let pdfURLString = metadata.bestOALocation?.pdfURL,
                  let pdfURL = URL(string: pdfURLString) else {
                return (nil, false, .notFound)
            }

            let (pdfData, _) = try await URLSession.shared.data(from: pdfURL)
            let storedURL = try store.saveDownloadedPDF(pdfData, referenceID: reference.id)
            return (storedURL, true, .found)
        } catch {
            return (nil, false, .error)
        }
    }
}
