import SwiftUI

/// 状态栏菜单顶部的「用量详情」区块：按平台分页签（下划线式；仅一个平台启用时隐藏页签栏）
/// 智谱AI：5 小时额度与周额度（百分比、积分使用、重置时间）；DeepSeek：余额及赠送/充值拆分
struct UsageDetailsMenuView: View {
    @ObservedObject var state: AppState
    /// 用户点选的页签；未点选或所选平台已停用时回落到第一个启用平台（菜单视图常驻，选择在会话内保留）
    @State private var selectedPlatform: Platform?

    private var platforms: [Platform] { state.config.enabledPlatforms }

    /// 当前生效页签：platforms 非空时必有值
    private var selection: Platform? {
        if let selectedPlatform, platforms.contains(selectedPlatform) { return selectedPlatform }
        return platforms.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if platforms.count > 1 {
                tabBar
            }
            if platforms.isEmpty {
                Text("没有启用的平台")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            } else {
                platformContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // 固定宽度：数据刷新时菜单宽度不跳动；高度结构恒定（无数据时显示占位符）
        .frame(width: 220, alignment: .leading)
    }

    /// 页签栏：启用平台各一签，点选切换
    private var tabBar: some View {
        HStack(spacing: 14) {
            ForEach(platforms) { platform in
                TabItem(platform: platform, isSelected: platform == selection) {
                    selectedPlatform = platform
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// 内容区：两页常驻布局、仅选中页可见，ZStack 取最高页高度，切页签时菜单高度不跳动（DeepSeek 页下方留白）
    private var platformContent: some View {
        ZStack(alignment: .top) {
            if state.config.zhipu.enabled {
                zhipuContent
                    .opacity(selection == .zhipu ? 1 : 0)
            }
            if state.config.deepseek.enabled {
                BalanceBlock(
                    balance: state.deepSeekBalance,
                    threshold: state.config.deepseek.lowBalanceThreshold
                )
                .opacity(selection == .deepseek ? 1 : 0)
            }
        }
    }

    /// 智谱页：5 小时与周两个额度块
    private var zhipuContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            QuotaBlock(
                title: "5小时额度",
                detail: state.zhipuUsage?.fiveHour,
                scheme: state.config.colorDisplayScheme,
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.fiveHourWindowMinutes
            )
            Divider()
            QuotaBlock(
                title: "周额度",
                detail: state.zhipuUsage?.weekly,
                scheme: state.config.colorDisplayScheme,
                usageScheme: state.config.usageDisplayScheme,
                windowMinutes: UsageSummary.weeklyWindowMinutes
            )
        }
    }
}

/// 下划线式页签项：平台图标 + 名称，选中项加粗并带系统色下划线
private struct TabItem: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            if let icon = PlatformIcon.defaultIcon(for: platform) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: platform == .zhipu ? 15 : 12)
            }
            Text(platform.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(Color(nsColor: isSelected ? .labelColor : .secondaryLabelColor))
        }
        // 下划线以 overlay 绘制（与页签内容等宽、不参与布局），向下偏移落进页签栏与内容区的间距里
        .overlay(alignment: .bottom) {
            if isSelected {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .offset(y: 5)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
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

/// DeepSeek 余额块：标题行显示总余额（与菜单栏圆点同色），下拆赠送 / 充值
private struct BalanceBlock: View {
    let balance: BalanceSummary?
    let threshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("余额")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Text(balance?.displayText ?? "¥--")
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(balanceColor(for: balance, threshold: threshold))
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                GridRow {
                    Text("赠送")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Text(balance.map { BalanceSummary.amountText($0.granted) } ?? "--")
                        .font(.system(size: 12).monospacedDigit())
                        .gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text("充值")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Text(balance.map { BalanceSummary.amountText($0.toppedUp) } ?? "--")
                        .font(.system(size: 12).monospacedDigit())
                        .gridColumnAlignment(.trailing)
                }
                if balance?.isAvailable == false {
                    GridRow {
                        Text("状态")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        Text("不可用")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
        }
    }
}
