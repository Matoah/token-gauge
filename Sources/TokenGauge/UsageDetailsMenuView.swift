import SwiftUI

/// 状态栏菜单顶部的「用量详情」区块：
/// 分为 5 小时额度与周额度，各自展示百分比（已使用/剩余，依用量显示方案）、积分使用（currentValue/usage）与重置时间
struct UsageDetailsMenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("用量详情")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            QuotaBlock(
                title: "5小时额度",
                detail: state.usage?.fiveHour,
                scheme: state.config.colorDisplayScheme,
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.fiveHourWindowMinutes
            )
            Divider()
            QuotaBlock(
                title: "周额度",
                detail: state.usage?.weekly,
                scheme: state.config.colorDisplayScheme,
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.weeklyWindowMinutes
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        // 固定宽度：数据刷新时菜单宽度不跳动；高度结构恒定（无数据时显示占位符）
        .frame(width: 210, alignment: .leading)
    }
}

private struct QuotaBlock: View {
    let title: String
    let detail: QuotaDetail?
    let scheme: ColorDisplayScheme
    let usageScheme: UsageDisplayScheme
    let windowMinutes: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Text(detail.map { "\($0.displayPercent(scheme: usageScheme))%" } ?? "--%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    // 与菜单栏对应行圆点同色：配色始终基于实际用量（按进度方案取推算值），与所显数字方案无关
                    .foregroundStyle(usageColor(for: detail, scheme: scheme, windowMinutes: windowMinutes))
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                GridRow {
                    Text("积分")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Text(pointsText)
                        .font(.system(size: 12).monospacedDigit())
                        .gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text("重置")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Text(resetText)
                        .font(.system(size: 12).monospacedDigit())
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }

    /// 积分使用详情：currentValue / usage，千分位格式化
    private var pointsText: String {
        guard let detail else { return "--" }
        return "\(Self.thousands(detail.currentValue)) / \(Self.thousands(detail.usage))"
    }

    /// 重置时间：yyyy-MM-dd HH:mm
    private var resetText: String {
        guard let date = detail?.nextResetTime else { return "--" }
        return Self.resetFormatter.string(from: date)
    }

    private static let thousandsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        // 固定使用 "," 千分位，不随系统语言变化
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func thousands(_ value: Int) -> String {
        thousandsFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
