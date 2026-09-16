import AppKit

@main
enum TokenGaugeMain {
    @MainActor
    static func main() {
        // 菜单栏应用：不显示 Dock 图标（配合 Info.plist 的 LSUIElement）
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
