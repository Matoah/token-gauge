import SwiftUI

/// 配置界面：平台 / 查询 / 通用 / 登录时打开
struct ConfigView: View {
    @ObservedObject var state: AppState

    @State private var draft = Config()
    @State private var selectedPlatform: Platform = .zhipu
    @StateObject private var loginItem = LoginItemController()

    var body: some View {
        Form {
            Section {
                Picker("平台", selection: $selectedPlatform) {
                    ForEach(Platform.allCases) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                switch selectedPlatform {
                case .zhipu:
                    ZhipuFields(config: $draft.zhipu)
                case .deepseek:
                    DeepSeekFields(config: $draft.deepseek)
                }
            } header: {
                Text("平台配置")
            }

            Section("查询（全局）") {
                Stepper(value: $draft.timeoutSeconds, in: 1...600) {
                    Text("超时时间：\(draft.timeoutSeconds) 秒")
                }
                Stepper(value: $draft.intervalMinutes, in: 0...1440) {
                    Text("自动查询间隔：\(draft.intervalMinutes) 分钟\(draft.intervalMinutes == 0 ? "（不自动查询）" : "")")
                }
                Stepper(value: $draft.rotationSeconds, in: 0...60) {
                    Text("轮询间隔：\(draft.rotationSeconds) 秒\(draft.rotationSeconds == 0 ? "（不轮询，固定显示第一个启用平台）" : "")")
                }
            }

            Section("通用") {
                Picker("显示模式", selection: $draft.displayMode) {
                    ForEach(StatusBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Picker("颜色显示方案", selection: $draft.colorDisplayScheme) {
                    ForEach(ColorDisplayScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.radioGroup)
                Picker("用量显示方案", selection: $draft.usageDisplayScheme) {
                    ForEach(UsageDisplayScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.radioGroup)
                Toggle("登录时打开", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.requiresApproval {
                    HStack {
                        Label("登录项待系统允许", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        Button("前往系统设置") {
                            loginItem.openSystemSettings()
                        }
                    }
                }
                if let error = loginItem.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            Section {
                HStack {
                    Button("保存并刷新") {
                        state.apply(draft)
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("立即刷新") {
                        state.refresh()
                    }
                    Spacer()
                    Button("放弃更改") {
                        draft = state.config
                    }
                }
            }

            Section("状态") {
                ForEach(Platform.allCases) { platform in
                    if state.config.isPlatformEnabled(platform) {
                        platformStatus(platform)
                    }
                }
                if state.config.enabledPlatforms.isEmpty {
                    Text("没有启用的平台，菜单栏将显示占位符")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(legend)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            draft = state.config
        }
    }

    @ViewBuilder
    private func platformStatus(_ platform: Platform) -> some View {
        if let error = state.errors[platform] {
            Label("\(platform.displayName)：\(error)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .textSelection(.enabled)
        } else if let update = state.updates[platform] {
            Text("\(platform.displayName)：上次更新 \(update.formatted(date: .omitted, time: .standard))")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            Text("\(platform.displayName)：尚未查询")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// 状态区说明文字，随显示模式与所选方案变化
    private var legend: String {
        switch draft.displayMode {
        case .normal:
            var text = "菜单栏轮播显示已启用平台：图标 + 彩点 + 数值，宽度固定为最宽帧；\n轮询间隔 \(draft.rotationSeconds) 秒（0 = 固定显示第一个启用平台）。\n"
            text += "智谱AI：上下两行为 5 小时与周用量，百分比数字为\(draft.usageDisplayScheme == .used ? "已使用" : "剩余")百分比。" + colorLegend
            text += "\nDeepSeek：显示账户余额，配色为余额 ≤ 低余额阈值 红色、≤ 3×阈值 蓝色、其余绿色。"
            return text
        case .minimal:
            var text = "菜单栏仅显示图标（简约模式），多平台时按轮询间隔 \(draft.rotationSeconds) 秒轮播图标（0 = 固定第一个启用平台），宽度固定为最宽帧。\n"
            text += "智谱AI：图标颜色同 5 小时额度彩点，" + colorLegend
            text += "\nDeepSeek：图标颜色同余额彩点，余额 ≤ 低余额阈值 红色、≤ 3×阈值 蓝色、其余绿色。"
            text += "\n详细数值（百分比、积分、重置时间、余额拆分）见菜单栏下拉「用量详情」，其中百分比数字由「用量显示方案」决定。"
            return text
        }
    }

    /// 配色说明，随所选颜色显示方案变化
    private var colorLegend: String {
        switch draft.colorDisplayScheme {
        case .usage:
            return "按用量显示：已使用百分比 ≤30% 绿色，30%–70% 蓝色，>70% 红色。"
        case .progress:
            return "按进度显示：按当前消耗速率推算周期结束时的用量配色，≤80% 绿色，80%–100% 蓝色，>100% 红色；"
        }
    }
}

/// 智谱AI 平台字段
private struct ZhipuFields: View {
    @Binding var config: ZhipuConfig

    var body: some View {
        Toggle("启用此平台", isOn: $config.enabled)
        TextField("请求地址", text: $config.baseURL, prompt: Text("https://example.com/api/limit"))
            .textFieldStyle(.roundedBorder)
        APIKeyField(value: $config.apiKey)
    }
}

/// DeepSeek 平台字段
private struct DeepSeekFields: View {
    @Binding var config: DeepSeekConfig

    var body: some View {
        Toggle("启用此平台", isOn: $config.enabled)
        TextField("请求地址", text: $config.baseURL, prompt: Text(DeepSeekConfig.defaultBaseURL))
            .textFieldStyle(.roundedBorder)
        APIKeyField(value: $config.apiKey)
        Stepper(value: $config.lowBalanceThreshold, in: 0...10_000, step: 1) {
            Text("低余额阈值：\(config.lowBalanceThreshold, format: .number.precision(.fractionLength(0...2)))")
        }
    }
}

/// API Key 输入框：默认密文，点击尾部眼睛图标切换明文查看
private struct APIKeyField: View {
    @Binding var value: String
    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                TextField("API Key", text: $value, prompt: Text(placeholder))
            } else {
                SecureField("API Key", text: $value, prompt: Text(placeholder))
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(.trailing, 24)
        .overlay(alignment: .trailing) {
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isVisible ? "隐藏 API Key" : "显示 API Key")
            .accessibilityLabel(isVisible ? "隐藏 API Key" : "显示 API Key")
        }
    }

    private var placeholder: String {
        "留空则不携带 Authorization 请求头"
    }
}
