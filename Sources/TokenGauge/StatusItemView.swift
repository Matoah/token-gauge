import SwiftUI

/// 菜单栏状态项内容：两行（上=5小时用量，下=周用量），每行左侧彩点 + 右侧百分比
struct StatusItemView: View {
    @ObservedObject var state: AppState

    var body: some View {
        // 菜单栏按钮可用高度约 22pt，内容必须控制在此以内，否则会被压缩裁切
        VStack(alignment: .leading, spacing: 0) {
            UsageRow(percent: state.fiveHourPercent)
            UsageRow(percent: state.weeklyPercent)
        }
        .padding(.horizontal, 3)
    }
}

private struct UsageRow: View {
    let percent: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5.5, height: 5.5)
            Text(percent.map { "\($0)%" } ?? "--%")
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// [0%,30%] 绿色；(30%,70%] 蓝色；(70%,100%] 红色
    private var color: Color {
        guard let percent, percent >= 0 else { return .gray }
        if percent <= 30 { return .green }
        if percent <= 70 { return .blue }
        return .red
    }
}

/// 点击事件穿透到 NSStatusBarButton，保证菜单能正常弹出
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
