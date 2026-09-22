import Foundation

struct UsageResponse: Decodable {
    let code: Int
    let msg: String?
    let data: UsageData?
    let success: Bool
}

struct UsageData: Decodable {
    let limits: [UsageLimit]?
    let level: String?
}

struct UsageLimit: Decodable {
    let type: String
    let unit: Int          // 3 = 5 小时用量；6 = 周用量
    let number: Int
    let usage: Int
    let currentValue: Int
    let remaining: Int
    let percentage: Double
    let nextResetTime: Int64?
}

/// 单个额度（5 小时 / 周）的用量详情
struct QuotaDetail: Equatable {
    var percent: Int
    var currentValue: Int
    var usage: Int
    var nextResetTime: Date?

    /// 依用量显示方案返回展示用的百分比数字：已使用 / 剩余（超出额度时剩余为 0）
    func displayPercent(scheme: UsageDisplayScheme) -> Int {
        switch scheme {
        case .used: return percent
        case .remaining: return max(100 - percent, 0)
        }
    }

    /// 按进度显示方案的进度：以分钟粒度，按当前消耗速率推算整个周期结束时的用量百分比，可超过 100。
    /// 已使用时间（分钟）由「周期总长 − 距重置的剩余时间」倒推；总积分为 0、或已消耗但缺少重置时间时无法推算，返回 nil。
    /// 未消耗（currentValue = 0）推算必为 0%，无需重置时间（智谱对未使用窗口不返回 nextResetTime）
    func projectedPercent(windowMinutes: Double, now: Date = Date()) -> Double? {
        guard usage > 0 else { return nil }
        guard currentValue > 0 else { return 0 }
        guard let reset = nextResetTime else { return nil }
        let windowSeconds = windowMinutes * 60
        // 数据过期（已过重置时间）时按整个周期作为已使用时间
        let remaining = reset.timeIntervalSince(now)
        let elapsed = min(max(windowSeconds - remaining, 1), windowSeconds)
        return Double(currentValue) / elapsed * windowSeconds * 100 / Double(usage)
    }
}

/// 从接口数据中提取的用量摘要
struct UsageSummary: Equatable {
    /// 周期总长（分钟），用于按进度显示方案推算
    static let fiveHourWindowMinutes: Double = 5 * 60
    static let weeklyWindowMinutes: Double = 7 * 24 * 60

    var fiveHour: QuotaDetail?
    var weekly: QuotaDetail?

    init(limits: [UsageLimit]) {
        func detail(ofUnit unit: Int) -> QuotaDetail? {
            guard let limit = limits.first(where: { $0.unit == unit }) else { return nil }
            return QuotaDetail(
                percent: Int(limit.percentage.rounded()),
                currentValue: limit.currentValue,
                usage: limit.usage,
                nextResetTime: Self.parseDate(limit.nextResetTime)
            )
        }
        fiveHour = detail(ofUnit: 3)
        weekly = detail(ofUnit: 6)
    }

    /// 接口时间戳可能为秒级或毫秒级，按量级归一为秒
    private static func parseDate(_ epoch: Int64?) -> Date? {
        guard let epoch, epoch > 0 else { return nil }
        let seconds = epoch >= 100_000_000_000 ? Double(epoch) / 1000 : Double(epoch)
        return Date(timeIntervalSince1970: seconds)
    }
}

// MARK: - DeepSeek 余额

/// DeepSeek 余额接口响应
struct BalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

struct BalanceInfo: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

/// 余额三档配色区间（对应低余额阈值）
enum BalanceColorBand {
    /// 余额 ≤ 阈值
    case low
    /// 阈值 < 余额 ≤ 3×阈值
    case nearing
    /// 余额 > 3×阈值
    case plenty
}

/// 从余额接口数据中提取的余额摘要（金额为账户币种，DeepSeek 为 CNY）
struct BalanceSummary: Equatable {
    var currency: String
    var total: Double
    var granted: Double
    var toppedUp: Double
    var isAvailable: Bool

    init?(from response: BalanceResponse) {
        // DeepSeek 实际只返回 CNY；防御性取 CNY 条目，否则取第一条
        guard let info = response.balanceInfos.first(where: { $0.currency == "CNY" })
                ?? response.balanceInfos.first,
              let total = Self.amount(info.totalBalance),
              let granted = Self.amount(info.grantedBalance),
              let toppedUp = Self.amount(info.toppedUpBalance) else { return nil }
        currency = info.currency
        self.total = total
        self.granted = granted
        self.toppedUp = toppedUp
        isAvailable = response.isAvailable
    }

    /// 币种符号；未知币种为空（数字前直接显示原币种代码的场景由详情页承担）
    var currencySymbol: String {
        switch currency {
        case "CNY": return "¥"
        case "USD": return "$"
        default: return ""
        }
    }

    /// 菜单栏 / 详情标题行的显示文本，如「¥25.91」；非 CNY/USD 时前缀币种代码如「EUR 25.91」
    var displayText: String {
        let amount = Self.amountText(total)
        return currencySymbol.isEmpty ? "\(currency) \(amount)" : currencySymbol + amount
    }

    /// 依低余额阈值取配色区间
    func colorBand(threshold: Double) -> BalanceColorBand {
        if total <= threshold { return .low }
        if total <= threshold * 3 { return .nearing }
        return .plenty
    }

    private static func amount(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces))
    }

    /// 金额文本：固定两位小数 + "," 千分位（不随系统语言变化）
    static func amountText(_ value: Double) -> String {
        amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
