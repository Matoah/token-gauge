import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    /// 智谱AI 用量摘要（出错时保留上次成功数据）
    @Published private(set) var zhipuUsage: UsageSummary?
    /// DeepSeek 余额摘要（出错时保留上次成功数据）
    @Published private(set) var deepSeekBalance: BalanceSummary?
    /// 各平台上次成功查询时间
    @Published private(set) var updates: [Platform: Date] = [:]
    /// 各平台最近一次错误；nil 表示无错误（或尚未查询）
    @Published private(set) var errors: [Platform: String] = [:]
    @Published private(set) var config: Config
    /// 菜单栏轮播当前帧序号（使用时对 enabledPlatforms.count 取模）
    @Published private(set) var rotationIndex = 0

    private var queryTimer: Timer?
    private var rotationTimer: Timer?
    private let service = UsageService()

    init(config: Config = Config.load()) {
        self.config = config
    }

    /// 启动：有启用的平台则立即查询一次，并按间隔安排自动查询与轮播
    func start() {
        if !config.enabledPlatforms.isEmpty {
            refresh()
        }
        rescheduleQueryTimer()
        rescheduleRotationTimer()
    }

    /// 轮播当前显示的平台：不轮询时固定第一个启用平台；无启用平台返回 nil（菜单栏显示占位符）
    var currentPlatform: Platform? {
        let platforms = config.enabledPlatforms
        guard !platforms.isEmpty else { return nil }
        guard config.rotationSeconds > 0, platforms.count > 1 else { return platforms[0] }
        return platforms[rotationIndex % platforms.count]
    }

    /// 保存新配置并立即生效（持久化 + 重排定时器 + 立即查询）
    func apply(_ newConfig: Config) {
        config = newConfig
        newConfig.store()
        rescheduleQueryTimer()
        rescheduleRotationTimer()
        refresh()
    }

    func refresh() {
        let cfg = config
        refreshZhipu(with: cfg)
        refreshDeepSeek(with: cfg)
    }

    private func refreshZhipu(with cfg: Config) {
        guard cfg.zhipu.enabled else {
            errors[.zhipu] = nil
            return
        }
        guard !cfg.zhipu.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errors[.zhipu] = "尚未配置请求地址"
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await self.service.fetchUsage(config: cfg.zhipu, timeoutSeconds: cfg.timeoutSeconds)
                self.zhipuUsage = summary
                self.updates[.zhipu] = Date()
                self.errors[.zhipu] = nil
            } catch {
                self.errors[.zhipu] = error.localizedDescription
            }
        }
    }

    private func refreshDeepSeek(with cfg: Config) {
        guard cfg.deepseek.enabled else {
            errors[.deepseek] = nil
            return
        }
        guard !cfg.deepseek.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errors[.deepseek] = "尚未配置请求地址"
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let balance = try await self.service.fetchBalance(config: cfg.deepseek, timeoutSeconds: cfg.timeoutSeconds)
                self.deepSeekBalance = balance
                self.updates[.deepseek] = Date()
                self.errors[.deepseek] = nil
            } catch {
                self.errors[.deepseek] = error.localizedDescription
            }
        }
    }

    private func rescheduleQueryTimer() {
        queryTimer?.invalidate()
        queryTimer = nil
        let minutes = config.intervalMinutes
        guard minutes > 0 else { return }
        queryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// 轮播定时器：仅在不轮询关闭且多平台启用时运转；切帧只是显示层行为，不触发网络请求
    private func rescheduleRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        let seconds = config.rotationSeconds
        guard seconds > 0, config.enabledPlatforms.count > 1 else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rotationIndex += 1
            }
        }
    }
}
