import Foundation
import Security

struct APIConnectionStore {
    private let defaults: UserDefaults
    private let connectionsKey = "ai.connections"
    private let setupCompleteKey = "ai.setup.complete"
    private let service = "com.igv.reviewer.ai"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConnections() -> [AIConnection] {
        guard let data = defaults.data(forKey: connectionsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AIConnection].self, from: data)) ?? []
    }

    func saveConnections(_ connections: [AIConnection]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(connections) else { return }
        defaults.set(data, forKey: connectionsKey)
    }

    func setSetupComplete(_ complete: Bool) {
        defaults.set(complete, forKey: setupCompleteKey)
    }

    func isSetupComplete() -> Bool {
        defaults.bool(forKey: setupCompleteKey)
    }

    func saveAPIKey(_ apiKey: String, for connectionID: UUID) {
        let account = connectionID.uuidString
        let data = Data(apiKey.utf8)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    func hasAPIKey(for connectionID: UUID) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: connectionID.uuidString,
            kSecReturnData: false,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func apiKey(for connectionID: UUID) -> String? {
        var item: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: connectionID.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    func removeAPIKey(for connectionID: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: connectionID.uuidString
        ]

        SecItemDelete(query as CFDictionary)
    }
}
