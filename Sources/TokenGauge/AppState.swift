import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var fiveHourPercent: Int?
    @Published private(set) var weeklyPercent: Int?
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var config: Config

    private var timer: Timer?
    private let service = UsageService()

    init(config: Config = Config.load()) {
        self.config = config
    }

    /// 启动：已有配置则立即查询一次，并按间隔安排自动查询
    func start() {
        if isConfigured {
            refresh()
        }
        rescheduleTimer()
    }

    var isConfigured: Bool {
        !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 保存新配置并立即生效（持久化 + 重排定时器 + 立即查询）
    func apply(_ newConfig: Config) {
        config = newConfig
        newConfig.store()
        rescheduleTimer()
        refresh()
    }

    func refresh() {
        guard isConfigured else {
            lastError = "尚未配置请求地址，请点击「打开T·量」完成配置"
            return
        }
        let cfg = config
        Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await self.service.fetch(config: cfg)
                self.fiveHourPercent = summary.fiveHourPercent
                self.weeklyPercent = summary.weeklyPercent
                self.lastUpdate = Date()
                self.lastError = nil
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        let minutes = config.intervalMinutes
        guard minutes > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
}
