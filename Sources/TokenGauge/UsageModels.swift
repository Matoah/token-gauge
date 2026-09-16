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
    /// 已使用时间（分钟）由「周期总长 − 距重置的剩余时间」倒推；缺少重置时间或总积分为 0 时无法推算，返回 nil
    func projectedPercent(windowMinutes: Double, now: Date = Date()) -> Double? {
        guard usage > 0, let reset = nextResetTime else { return nil }
        guard currentValue > 0 else { return 0 }
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
