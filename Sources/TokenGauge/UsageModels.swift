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

/// 从接口数据中提取的用量摘要
struct UsageSummary: Equatable {
    var fiveHourPercent: Int?
    var weeklyPercent: Int?

    init(limits: [UsageLimit]) {
        func percent(ofUnit unit: Int) -> Int? {
            limits.first { $0.unit == unit }.map { Int($0.percentage.rounded()) }
        }
        fiveHourPercent = percent(ofUnit: 3)
        weeklyPercent = percent(ofUnit: 6)
    }
}
