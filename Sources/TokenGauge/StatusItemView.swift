import SwiftUI

/// 菜单栏状态项单帧内容，按显示模式渲染：
/// 普通模式：平台图标 + 该平台的「彩点 + 数值」（智谱上下两行、DeepSeek 单行余额；无启用平台灰点占位）
/// 简约模式：仅图标，颜色跟该平台彩点颜色一致（智谱取 5 小时额度、DeepSeek 取余额）
struct StatusFrameView: View {
    @ObservedObject var state: AppState
    /// 渲染层测量各帧宽度时显式指定；缺省取当前轮播帧
    let platform: Platform?

    init(state: AppState, platform: Platform? = nil) {
        self.state = state
        self.platform = platform ?? state.currentPlatform
    }

    var body: some View {
        switch state.config.displayMode {
        case .normal: normalBody
        case .minimal: minimalBody
        }
    }

    /// 普通模式帧：图标 + 「彩点 + 数值」
    /// 左右不留内边距：外侧由 updateStatusItemLength 的 +8 统一控制为每侧 4pt
    private var normalBody: some View {
        HStack(alignment: .center, spacing: 3) {
            if let platform, let icon = iconImage(for: platform) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.statusIconHeight(for: platform))
            }
            values
        }
    }

    /// 简约模式帧：仅图标，以该平台彩点颜色渲染为单色剪影；无启用平台（或图标缺失）时灰色占位
    private var minimalBody: some View {
        Group {
            if let platform, let icon = iconImage(for: platform) {
                Image(nsImage: PlatformIcon.tintedSilhouette(of: icon, color: NSColor(iconTint(for: platform))))
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.statusIconHeight(for: platform))
            } else {
                Image(systemName: "slash.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
        }
    }

    private func iconImage(for platform: Platform) -> NSImage? {
        PlatformIcon.defaultIcon(for: platform)
    }

    /// 简约模式的图标颜色：与该平台彩点同源（智谱取 5 小时额度，DeepSeek 取余额），无数据为灰色
    private func iconTint(for platform: Platform) -> Color {
        switch platform {
        case .zhipu:
            return usageColor(
                for: state.zhipuUsage?.fiveHour,
                scheme: state.config.colorDisplayScheme,
                windowMinutes: UsageSummary.fiveHourWindowMinutes
            )
        case .deepseek:
            return balanceColor(
                for: state.deepSeekBalance,
                threshold: state.config.deepseek.lowBalanceThreshold
            )
        }
    }

    /// 菜单栏图标渲染高度：智谱为「方块内套 Z」的构图，等高时观感明显小于满幅的 DeepSeek 鲸鱼，
    /// 放大到与鲸鱼等宽（内层 Z 接近鲸鱼高度）；DeepSeek 取常规 14pt
    private static func statusIconHeight(for platform: Platform) -> CGFloat {
        platform == .zhipu ? 19 : 14
    }

    @ViewBuilder
    private var values: some View {
        switch platform {
        case .zhipu:
            VStack(alignment: .leading, spacing: 0) {
                UsageRow(
                    detail: state.zhipuUsage?.fiveHour,
                    scheme: state.config.colorDisplayScheme,
                    usageScheme: state.config.usageDisplayScheme,
                    windowMinutes: UsageSummary.fiveHourWindowMinutes
                )
                UsageRow(
                    detail: state.zhipuUsage?.weekly,
                    scheme: state.config.colorDisplayScheme,
                    usageScheme: state.config.usageDisplayScheme,
                    windowMinutes: UsageSummary.weeklyWindowMinutes
                )
            }
        case .deepseek:
            StatusDotTextRow(
                text: state.deepSeekBalance?.displayText ?? "¥--",
                color: balanceColor(for: state.deepSeekBalance, threshold: state.config.deepseek.lowBalanceThreshold)
            )
        case nil:
            StatusDotTextRow(text: "--%", color: .gray)
        }
    }
}

private struct UsageRow: View {
    let detail: QuotaDetail?
    let scheme: ColorDisplayScheme
    let usageScheme: UsageDisplayScheme
    let windowMinutes: Double

    var body: some View {
        StatusDotTextRow(
            text: detail.map { "\($0.displayPercent(scheme: usageScheme))%" } ?? "--%",
            color: usageColor(for: detail, scheme: scheme, windowMinutes: windowMinutes)
        )
    }
}

/// 单行「彩点 + 文本」（菜单栏按钮可用高度约 22pt，字号须保持 9pt 档）
struct StatusDotTextRow: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5.5, height: 5.5)
            Text(text)
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

/// DeepSeek 余额三档配色（菜单栏圆点与详情数字同色）：≤阈值 红、(阈值,3×阈值] 蓝、否则绿；无数据灰色
func balanceColor(for balance: BalanceSummary?, threshold: Double) -> Color {
    guard let balance, balance.total >= 0 else { return .gray }
    switch balance.colorBand(threshold: threshold) {
    case .low: return .red
    case .nearing: return .blue
    case .plenty: return .green
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
