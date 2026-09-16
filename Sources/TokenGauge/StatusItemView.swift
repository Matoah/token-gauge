import SwiftUI

/// 菜单栏状态项内容：两行（上=5小时用量，下=周用量），每行左侧彩点 + 右侧百分比
struct StatusItemView: View {
    @ObservedObject var state: AppState

    var body: some View {
        // 菜单栏按钮可用高度约 22pt，内容必须控制在此以内，否则会被压缩裁切
        VStack(alignment: .leading, spacing: 0) {
            UsageRow(
                detail: state.usage?.fiveHour,
                scheme: state.config.colorDisplayScheme,
                windowHours: UsageSummary.fiveHourWindowHours
            )
            UsageRow(
                detail: state.usage?.weekly,
                scheme: state.config.colorDisplayScheme,
                windowHours: UsageSummary.weeklyWindowHours
            )
        }
        .padding(.horizontal, 3)
    }
}

private struct UsageRow: View {
    let detail: QuotaDetail?
    let scheme: ColorDisplayScheme
    let windowHours: Double

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(usageColor(for: detail, scheme: scheme, windowHours: windowHours))
                .frame(width: 5.5, height: 5.5)
            Text(detail.map { "\($0.percent)%" } ?? "--%")
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 依颜色显示方案取色：按用量看已使用百分比，按进度看推算的周期结束用量
func usageColor(for detail: QuotaDetail?, scheme: ColorDisplayScheme, windowHours: Double) -> Color {
    switch scheme {
    case .usage:
        return usageColor(for: detail?.percent)
    case .progress:
        guard let progress = detail?.projectedPercent(windowHours: windowHours) else { return .gray }
        // [0,80] 绿色；(80,100] 蓝色；(100,∞) 红色
        if progress <= 80 { return .green }
        if progress <= 100 { return .blue }
        return .red
    }
}

/// 按用量显示：[0%,30%] 绿色；(30%,70%] 蓝色；(70%,100%] 红色；无数据灰色
func usageColor(for percent: Int?) -> Color {
    guard let percent, percent >= 0 else { return .gray }
    if percent <= 30 { return .green }
    if percent <= 70 { return .blue }
    return .red
}
