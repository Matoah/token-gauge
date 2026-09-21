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

/// 菜单栏显示模式
enum StatusBarDisplayMode: String, CaseIterable {
    /// 普通模式：图标 + 彩点 + 数值
    case normal
    /// 简约模式：仅图标，颜色跟该平台彩点颜色逻辑一致
    case minimal

    var displayName: String {
        switch self {
        case .normal: return "普通模式：图标 + 彩点 + 数值"
        case .minimal: return "简约模式：仅图标，颜色指示额度状态"
        }
    }
}

/// 用量显示方案：百分比数字展示已使用还是剩余
enum UsageDisplayScheme: String, CaseIterable {
    /// 已使用百分比
    case used
    /// 剩余百分比
    case remaining

    var displayName: String {
        switch self {
        case .used: return "已使用百分比"
        case .remaining: return "剩余百分比"
        }
    }
}

/// 支持的 AI 平台（菜单栏轮播与详情分组的顺序）
enum Platform: String, CaseIterable, Identifiable {
    /// 智谱AI：配额型，5 小时 / 周额度用量
    case zhipu
    /// DeepSeek：余额型，仅账户余额
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhipu: return "智谱AI"
        case .deepseek: return "DeepSeek"
        }
    }
}

/// 智谱AI 平台配置
struct ZhipuConfig: Equatable {
    var enabled: Bool = true
    var baseURL: String = ""
    var apiKey: String = ""
}

/// DeepSeek 平台配置
struct DeepSeekConfig: Equatable {
    static let defaultBaseURL = "https://api.deepseek.com/user/balance"

    var enabled: Bool = false
    var baseURL: String = defaultBaseURL
    var apiKey: String = ""
    /// 低余额阈值（账户币种，DeepSeek 为 CNY）：余额 ≤ 阈值红色、(阈值, 3×阈值] 蓝色、否则绿色；0 表示仅余额 ≤ 0 时红色
    var lowBalanceThreshold: Double = 10
}

/// 用户配置，持久化到 UserDefaults
struct Config: Equatable {
    var zhipu = ZhipuConfig()
    var deepseek = DeepSeekConfig()
    var timeoutSeconds: Int = 10
    var intervalMinutes: Int = 5   // 0 表示不自动查询
    /// 菜单栏轮播间隔（秒）；0 表示不轮询，固定显示第一个启用平台
    var rotationSeconds: Int = 5
    var displayMode: StatusBarDisplayMode = .normal
    var colorDisplayScheme: ColorDisplayScheme = .usage
    var usageDisplayScheme: UsageDisplayScheme = .used

    /// 已启用的平台（按 Platform.allCases 顺序）
    var enabledPlatforms: [Platform] {
        Platform.allCases.filter { isPlatformEnabled($0) }
    }

    func isPlatformEnabled(_ platform: Platform) -> Bool {
        switch platform {
        case .zhipu: return zhipu.enabled
        case .deepseek: return deepseek.enabled
        }
    }

    private enum Keys {
        static let zhipuEnabled = "config.zhipu.enabled"
        static let zhipuBaseURL = "config.zhipu.baseURL"
        static let zhipuAPIKey = "config.zhipu.apiKey"
        static let deepseekEnabled = "config.deepseek.enabled"
        static let deepseekBaseURL = "config.deepseek.baseURL"
        static let deepseekAPIKey = "config.deepseek.apiKey"
        static let deepseekLowBalanceThreshold = "config.deepseek.lowBalanceThreshold"
        static let timeoutSeconds = "config.timeoutSeconds"
        static let intervalMinutes = "config.intervalMinutes"
        static let rotationSeconds = "config.rotationSeconds"
        static let displayMode = "config.displayMode"
        static let colorDisplayScheme = "config.colorDisplayScheme"
        static let usageDisplayScheme = "config.usageDisplayScheme"

        // 旧版单平台键：新键缺失时读取一次，迁入智谱平台
        static let legacyBaseURL = "config.baseURL"
        static let legacyAPIKey = "config.apiKey"
    }

    static func load(defaults: UserDefaults = .standard) -> Config {
        var config = Config()
        config.zhipu.enabled = (defaults.object(forKey: Keys.zhipuEnabled) as? Bool) ?? true
        if let url = defaults.string(forKey: Keys.zhipuBaseURL) {
            config.zhipu.baseURL = url
        } else if let legacy = defaults.string(forKey: Keys.legacyBaseURL) {
            config.zhipu.baseURL = legacy
        }
        if let key = defaults.string(forKey: Keys.zhipuAPIKey) {
            config.zhipu.apiKey = key
        } else if let legacy = defaults.string(forKey: Keys.legacyAPIKey) {
            config.zhipu.apiKey = legacy
        }

        config.deepseek.enabled = (defaults.object(forKey: Keys.deepseekEnabled) as? Bool) ?? false
        config.deepseek.baseURL = defaults.string(forKey: Keys.deepseekBaseURL) ?? DeepSeekConfig.defaultBaseURL
        config.deepseek.apiKey = defaults.string(forKey: Keys.deepseekAPIKey) ?? ""
        config.deepseek.lowBalanceThreshold = (defaults.object(forKey: Keys.deepseekLowBalanceThreshold) as? Double) ?? 10

        config.timeoutSeconds = defaults.object(forKey: Keys.timeoutSeconds) as? Int ?? 10
        config.intervalMinutes = defaults.object(forKey: Keys.intervalMinutes) as? Int ?? 5
        config.rotationSeconds = defaults.object(forKey: Keys.rotationSeconds) as? Int ?? 5
        config.displayMode = StatusBarDisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .normal
        config.colorDisplayScheme = ColorDisplayScheme(rawValue: defaults.string(forKey: Keys.colorDisplayScheme) ?? "") ?? .usage
        config.usageDisplayScheme = UsageDisplayScheme(rawValue: defaults.string(forKey: Keys.usageDisplayScheme) ?? "") ?? .used
        return config
    }

    func store() {
        let defaults = UserDefaults.standard
        defaults.set(zhipu.enabled, forKey: Keys.zhipuEnabled)
        defaults.set(zhipu.baseURL, forKey: Keys.zhipuBaseURL)
        defaults.set(zhipu.apiKey, forKey: Keys.zhipuAPIKey)
        defaults.set(deepseek.enabled, forKey: Keys.deepseekEnabled)
        defaults.set(deepseek.baseURL, forKey: Keys.deepseekBaseURL)
        defaults.set(deepseek.apiKey, forKey: Keys.deepseekAPIKey)
        defaults.set(deepseek.lowBalanceThreshold, forKey: Keys.deepseekLowBalanceThreshold)
        defaults.set(timeoutSeconds, forKey: Keys.timeoutSeconds)
        defaults.set(intervalMinutes, forKey: Keys.intervalMinutes)
        defaults.set(rotationSeconds, forKey: Keys.rotationSeconds)
        defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        defaults.set(colorDisplayScheme.rawValue, forKey: Keys.colorDisplayScheme)
        defaults.set(usageDisplayScheme.rawValue, forKey: Keys.usageDisplayScheme)
    }
}
