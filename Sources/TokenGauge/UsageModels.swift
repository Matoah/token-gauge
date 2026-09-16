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
}

/// 从接口数据中提取的用量摘要
struct UsageSummary: Equatable {
    var fiveHour: QuotaDetail?
    var weekly: QuotaDetail?

    var fiveHourPercent: Int? { fiveHour?.percent }
    var weeklyPercent: Int? { weekly?.percent }

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
