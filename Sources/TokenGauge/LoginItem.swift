import Foundation
import ServiceManagement

/// 「登录时打开」开关：注册/注销主应用登录项（SMAppService）。
/// 开关状态以系统登录项注册表为准（而非 UserDefaults），切换后立即生效，
/// 不随「保存并刷新」走草稿流程。
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastError: String?

    init() {
        refreshStatus()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = "设置登录项失败：\(error.localizedDescription)"
        }
        refreshStatus()
    }

    /// 登录项被系统标记为待允许时，引导用户到系统设置的登录项管理页
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = false
            requiresApproval = true
        default:
            isEnabled = false
            requiresApproval = false
        }
    }
}
