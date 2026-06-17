import Foundation

@MainActor
struct FullTextDocumentStore {
    private let fileManager: FileManager
    private let preferencesStore: AppPreferencesStore

    init(
        fileManager: FileManager = .default,
        preferencesStore: AppPreferencesStore? = nil
    ) {
        self.fileManager = fileManager
        self.preferencesStore = preferencesStore ?? AppPreferencesStore()
    }

    func importPDF(from sourceURL: URL, referenceID: String) throws -> URL {
        let destinationURL = destinationURL(for: referenceID)
        ensureDirectoryExists()

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func saveDownloadedPDF(_ data: Data, referenceID: String) throws -> URL {
        let destinationURL = destinationURL(for: referenceID)
        ensureDirectoryExists()
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func destinationURL(for referenceID: String) -> URL {
        pdfDirectoryURL().appendingPathComponent("\(referenceID).pdf")
    }

    private func pdfDirectoryURL() -> URL {
        preferencesStore.cacheDirectoryURL().appendingPathComponent("FullTextPDFs", isDirectory: true)
    }

    private func ensureDirectoryExists() {
        preferencesStore.ensureCacheDirectoryExists()
        try? fileManager.createDirectory(at: pdfDirectoryURL(), withIntermediateDirectories: true)
    }
}
