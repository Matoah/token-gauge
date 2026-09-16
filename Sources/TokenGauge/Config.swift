import Foundation

/// 颜色显示方案
enum ColorDisplayScheme: String, CaseIterable {
    /// 按用量显示：按已使用百分比配色
    case usage
    /// 按进度显示：按当前消耗速率推算的周期结束用量配色
    case progress

    var displayName: String {
        switch self {
        case .usage: return "按用量显示"
        case .progress: return "按进度显示"
        }
    }
}

/// 用户配置，持久化到 UserDefaults
struct Config: Equatable {
    var baseURL: String = ""
    var apiKey: String = ""
    var timeoutSeconds: Int = 10
    var intervalMinutes: Int = 1   // 0 表示不自动查询
    var colorDisplayScheme: ColorDisplayScheme = .usage

    private enum Keys {
        static let baseURL = "config.baseURL"
        static let apiKey = "config.apiKey"
        static let timeoutSeconds = "config.timeoutSeconds"
        static let intervalMinutes = "config.intervalMinutes"
        static let colorDisplayScheme = "config.colorDisplayScheme"
    }

    static func load() -> Config {
        let defaults = UserDefaults.standard
        return Config(
            baseURL: defaults.string(forKey: Keys.baseURL) ?? "",
            apiKey: defaults.string(forKey: Keys.apiKey) ?? "",
            timeoutSeconds: defaults.object(forKey: Keys.timeoutSeconds) as? Int ?? 10,
            intervalMinutes: defaults.object(forKey: Keys.intervalMinutes) as? Int ?? 1,
            colorDisplayScheme: ColorDisplayScheme(rawValue: defaults.string(forKey: Keys.colorDisplayScheme) ?? "") ?? .usage
        )
    }

    func store() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(apiKey, forKey: Keys.apiKey)
        defaults.set(timeoutSeconds, forKey: Keys.timeoutSeconds)
        defaults.set(intervalMinutes, forKey: Keys.intervalMinutes)
        defaults.set(colorDisplayScheme.rawValue, forKey: Keys.colorDisplayScheme)
    }
}
