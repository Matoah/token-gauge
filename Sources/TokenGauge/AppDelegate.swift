import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var statusHostView: PassthroughHostingView<StatusItemView>?
    private var configWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        state.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// 菜单栏应用没有主菜单时，Cmd+C/V/X 等快捷键无法经响应链分发到文本框，
    /// 需要挂一个标准的「编辑」菜单（目标为 nil，由第一响应者处理）
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "T·量")
        appMenu.addItem(NSMenuItem(
            title: "退出T·量",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 菜单栏状态项

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开T·量", action: #selector(openConfigWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu

        guard let button = item.button else { return }
        let host = PassthroughHostingView(rootView: StatusItemView(state: state))
        host.sizingOptions = [.intrinsicContentSize]
        host.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            host.topAnchor.constraint(equalTo: button.topAnchor),
            host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        statusHostView = host

        // 菜单栏按钮宽度不会自动跟随 SwiftUI 内容，需要手动设置长度
        updateStatusItemLength()
        Publishers.CombineLatest(state.$fiveHourPercent, state.$weeklyPercent)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemLength() }
            .store(in: &cancellables)
        // 首次布局完成后再校准一次，避免字体未就绪时测量偏小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateStatusItemLength()
        }
    }

    /// 按内容理想宽度调整状态项长度，保证百分比完整显示
    private func updateStatusItemLength() {
        guard let host = statusHostView, let item = statusItem else { return }
        let width = max(host.intrinsicContentSize.width, host.fittingSize.width)
        guard width.isFinite, width > 0 else { return }
        item.length = width + 8  // 左右各留少量边距
    }

    // MARK: - 配置窗口

    @objc private func openConfigWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if configWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: ConfigView(state: state))
            )
            window.title = "T·量"
            window.styleMask.insert(.closable)
            window.styleMask.insert(.miniaturizable)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("TokenGaugeConfigWindow")
            configWindow = window
        }
        configWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
