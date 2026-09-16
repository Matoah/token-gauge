import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var configWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?
    /// 上次渲染所用的深/浅色方案。设置 image / length 会让按钮重新解析 effectiveAppearance、
    /// 再次触发 appearance 观察，据此跳过方案未变的重复通知，避免渲染↔观察互相触发的死循环
    private var lastRenderedSchemeIsDark: Bool?

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

        // 用量详情（自定义视图，随数据刷新实时更新；无操作行为，不需要高亮）
        let detailsItem = NSMenuItem()
        let detailsHost = NSHostingView(rootView: UsageDetailsMenuView(state: state))
        detailsHost.frame = NSRect(origin: .zero, size: detailsHost.fittingSize)
        detailsItem.view = detailsHost
        menu.addItem(detailsItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "打开T·量", action: #selector(openConfigWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu

        guard let button = item.button else { return }
        // 用 NSImage 而非自绘子视图承载内容：系统会在副屏菜单栏自动压暗按钮自带内容，
        // 自定义子视图（NSHostingView）则始终保持高亮，与其它菜单栏图标不一致
        renderStatusImage()

        // 数值变化后重新渲染
        state.$usage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderStatusImage() }
            .store(in: &cancellables)
        // 外观（深/浅色）变化后按新配色重新渲染。
        // 注意：renderStatusImage 的副作用（设置 image、调整 length）会再次触发本观察，
        // 回调里必须比较方案是否实际变化，否则形成再入循环，主线程全速空转
        appearanceObservation = button.observe(\.effectiveAppearance, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in self?.renderStatusImageIfAppearanceChanged() }
        }
    }

    /// 把状态项内容渲染为位图并设置到按钮上
    private func renderStatusImage() {
        guard let button = statusItem?.button else { return }
        let isDark = Self.isDarkAppearance(button.effectiveAppearance)
        let content = StatusItemView(state: state)
            .environment(\.colorScheme, isDark ? .dark : .light)

        // 生成 1x/2x 两档位图：NSImage 绘制时按目标屏幕的 backing scale
        // 自动选择表示，避免在 1x 屏上把 2x 位图缩回 1x 造成文字发虚。
        // 以 1x 渲染结果作为基准点尺寸，保证 1x 屏上逐像素 1:1 显示
        let renderer1x = ImageRenderer(content: content)
        renderer1x.scale = 1
        guard let cg1x = renderer1x.cgImage else { return }
        let pointSize = NSSize(width: CGFloat(cg1x.width), height: CGFloat(cg1x.height))

        let image = NSImage(size: pointSize)
        let rep1x = NSBitmapImageRep(cgImage: cg1x)
        rep1x.size = pointSize
        image.addRepresentation(rep1x)

        let renderer2x = ImageRenderer(content: content)
        renderer2x.scale = 2
        renderer2x.proposedSize = ProposedViewSize(pointSize)
        if let cg2x = renderer2x.cgImage {
            let rep2x = NSBitmapImageRep(cgImage: cg2x)
            rep2x.size = pointSize
            image.addRepresentation(rep2x)
        }

        image.isTemplate = false
        button.image = image
        lastRenderedSchemeIsDark = isDark
        updateStatusItemLength()
    }

    /// appearance 观察回调：仅在解析出的深/浅色与上次渲染不同时才重渲染
    private func renderStatusImageIfAppearanceChanged() {
        guard let button = statusItem?.button else { return }
        let isDark = Self.isDarkAppearance(button.effectiveAppearance)
        guard isDark != lastRenderedSchemeIsDark else { return }
        renderStatusImage()
    }

    private static func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// 按图像宽度调整状态项长度，保证百分比完整显示
    private func updateStatusItemLength() {
        guard let button = statusItem?.button, let image = button.image, let item = statusItem else { return }
        item.length = image.size.width + 8  // 左右各留少量边距
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
