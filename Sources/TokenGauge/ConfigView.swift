import SwiftUI

/// 配置界面：请求地址 / API Key / 超时时间 / 自动查询间隔
struct ConfigView: View {
    @ObservedObject var state: AppState

    @State private var draft = Config()

    var body: some View {
        Form {
            Section("接口") {
                TextField("请求地址", text: $draft.baseURL, prompt: Text("https://example.com/api/limit"))
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $draft.apiKey, prompt: Text("留空则不携带 Authorization 请求头"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("查询") {
                Stepper(value: $draft.timeoutSeconds, in: 1...600) {
                    Text("超时时间：\(draft.timeoutSeconds) 秒")
                }
                Stepper(value: $draft.intervalMinutes, in: 0...1440) {
                    Text("自动查询间隔：\(draft.intervalMinutes) 分钟\(draft.intervalMinutes == 0 ? "（不自动查询）" : "")")
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
                if let error = state.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                if let update = state.lastUpdate {
                    Text("上次更新：\(update.formatted(date: .omitted, time: .standard))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("菜单栏第一行为 5 小时用量，第二行为周用量。用量 ≤30% 显示绿点，30%–70% 蓝点，>70% 红点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 430)
        .onAppear {
            draft = state.config
        }
    }
}
