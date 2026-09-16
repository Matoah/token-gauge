import Foundation

/// 用户配置，持久化到 UserDefaults
struct Config: Equatable {
    var baseURL: String = ""
    var apiKey: String = ""
    var timeoutSeconds: Int = 10
    var intervalMinutes: Int = 1   // 0 表示不自动查询

    private enum Keys {
        static let baseURL = "config.baseURL"
        static let apiKey = "config.apiKey"
        static let timeoutSeconds = "config.timeoutSeconds"
        static let intervalMinutes = "config.intervalMinutes"
    }

    static func load() -> Config {
        let defaults = UserDefaults.standard
        return Config(
            baseURL: defaults.string(forKey: Keys.baseURL) ?? "",
            apiKey: defaults.string(forKey: Keys.apiKey) ?? "",
            timeoutSeconds: defaults.object(forKey: Keys.timeoutSeconds) as? Int ?? 10,
            intervalMinutes: defaults.object(forKey: Keys.intervalMinutes) as? Int ?? 1
        )
    }

    func store() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(apiKey, forKey: Keys.apiKey)
        defaults.set(timeoutSeconds, forKey: Keys.timeoutSeconds)
        defaults.set(intervalMinutes, forKey: Keys.intervalMinutes)
    }
}
