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
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.fiveHourWindowMinutes
            )
            UsageRow(
                detail: state.usage?.weekly,
                scheme: state.config.colorDisplayScheme,
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.weeklyWindowMinutes
            )
        }
        .padding(.horizontal, 3)
    }
}

private struct UsageRow: View {
    let detail: QuotaDetail?
    let scheme: ColorDisplayScheme
    let usageScheme: UsageDisplayScheme
    let windowMinutes: Double

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(usageColor(for: detail, scheme: scheme, windowMinutes: windowMinutes))
                .frame(width: 5.5, height: 5.5)
            Text(detail.map { "\($0.displayPercent(scheme: usageScheme))%" } ?? "--%")
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 依颜色显示方案取色（菜单栏圆点与用量详情百分比文字同色）：
/// 按用量看已使用百分比，按进度看推算的周期结束用量
func usageColor(for detail: QuotaDetail?, scheme: ColorDisplayScheme, windowMinutes: Double) -> Color {
    switch scheme {
    case .usage:
        return schemeColor(for: detail.map { Double($0.percent) }, scheme: scheme)
    case .progress:
        return schemeColor(for: detail?.projectedPercent(windowMinutes: windowMinutes), scheme: scheme)
    }
}

/// 按方案的配色区间对百分比取色：按用量 [0,30] 绿、(30,70] 蓝、(70,∞) 红；
/// 按进度 [0,80] 绿、(80,100] 蓝、(100,∞) 红；无数据或负值灰色
private func schemeColor(for percent: Double?, scheme: ColorDisplayScheme) -> Color {
    guard let percent, percent >= 0 else { return .gray }
    let (greenMax, blueMax): (Double, Double) = scheme == .usage ? (30, 70) : (80, 100)
    if percent <= greenMax { return .green }
    if percent <= blueMax { return .blue }
    return .red
}
