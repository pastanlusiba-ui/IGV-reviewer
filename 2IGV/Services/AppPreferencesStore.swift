import Foundation

struct AppPreferencesStore {
    private let defaults: UserDefaults
    private let fileManager: FileManager

    private let appearanceKey = "settings.appearance"
    private let compactProjectCardsKey = "settings.project_cards.compact"
    private let syncOnLaunchKey = "settings.sync.on_launch"
    private let backgroundSyncEnabledKey = "settings.sync.background_enabled"
    private let syncIntervalMinutesKey = "settings.sync.interval_minutes"
    private let offlinePDFCachingEnabledKey = "settings.cache.offline_pdfs"
    private let cacheRetentionDaysKey = "settings.cache.retention_days"

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    func loadAppearancePreference() -> AppearancePreference {
        AppearancePreference(rawValue: defaults.string(forKey: appearanceKey) ?? "") ?? .system
    }

    func setAppearancePreference(_ preference: AppearancePreference) {
        defaults.set(preference.rawValue, forKey: appearanceKey)
    }

    func loadCompactProjectCards() -> Bool {
        defaults.object(forKey: compactProjectCardsKey) as? Bool ?? false
    }

    func setCompactProjectCards(_ enabled: Bool) {
        defaults.set(enabled, forKey: compactProjectCardsKey)
    }

    func loadSyncOnLaunch() -> Bool {
        defaults.object(forKey: syncOnLaunchKey) as? Bool ?? true
    }

    func setSyncOnLaunch(_ enabled: Bool) {
        defaults.set(enabled, forKey: syncOnLaunchKey)
    }

    func loadBackgroundSyncEnabled() -> Bool {
        defaults.object(forKey: backgroundSyncEnabledKey) as? Bool ?? true
    }

    func setBackgroundSyncEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: backgroundSyncEnabledKey)
    }

    func loadSyncIntervalMinutes() -> Int {
        let value = defaults.integer(forKey: syncIntervalMinutesKey)
        return value == 0 ? 15 : value
    }

    func setSyncIntervalMinutes(_ minutes: Int) {
        defaults.set(minutes, forKey: syncIntervalMinutesKey)
    }

    func loadOfflinePDFCachingEnabled() -> Bool {
        defaults.object(forKey: offlinePDFCachingEnabledKey) as? Bool ?? true
    }

    func setOfflinePDFCachingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: offlinePDFCachingEnabledKey)
    }

    func loadCacheRetentionDays() -> Int {
        let value = defaults.integer(forKey: cacheRetentionDaysKey)
        return value == 0 ? 30 : value
    }

    func setCacheRetentionDays(_ days: Int) {
        defaults.set(days, forKey: cacheRetentionDaysKey)
    }

    func cacheDirectoryURL() -> URL {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL.appendingPathComponent("IGVReviewer", isDirectory: true)
    }

    func ensureCacheDirectoryExists() {
        try? fileManager.createDirectory(at: cacheDirectoryURL(), withIntermediateDirectories: true)
    }

    func formattedCacheSize() -> String {
        let size = directorySize(at: cacheDirectoryURL())
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func clearCache() throws {
        let cacheURL = cacheDirectoryURL()
        ensureCacheDirectoryExists()

        let contents = try fileManager.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
