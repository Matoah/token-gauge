# T·量

macOS 菜单栏 Token 用量监视器。应用常驻系统菜单栏（无 Dock 图标），用两行「彩点 + 百分比」实时显示 Token 用量：

- 第一行：5 小时用量（接口返回 `unit = 3` 的条目）
- 第二行：周用量（接口返回 `unit = 6` 的条目）
- 颜色显示方案（可在配置中切换），决定菜单栏圆点与用量详情百分比的配色区间：
  - 按用量显示（默认）：按已使用百分比配色，`[0%, 30%]` 绿色；`(30%, 70%]` 蓝色；`(70%, 100%]` 红色
  - 按进度显示：菜单栏圆点按当前消耗速率推算整个周期结束时的用量配色，`[0%, 80%]` 绿色；`(80%, 100%]` 蓝色；`(100%, ∞)` 红色（需接口返回重置时间）；用量详情百分比按已使用百分比以同一区间配色

## 使用

```bash
bash scripts/build-app.sh        # 编译并打包为 build/T·量.app
open "build/T·量.app"
```

点击菜单栏中的用量显示，弹出菜单：

- **打开T·量**：打开配置窗口
- **退出**：退出应用

## 配置项

| 配置 | 说明 | 默认值 |
| --- | --- | --- |
| 请求地址 | 用量接口的完整 URL | 空 |
| API Key | 作为 `Authorization` 请求头发送 | 空（不发送） |
| 超时时间(秒) | 请求超时 | 10 |
| 自动查询间隔(分钟) | 定时刷新间隔，`0` 表示不自动查询 | 1 |
| 颜色显示方案 | 按用量 / 按进度配色，见上文说明 | 按用量显示 |
| 登录时打开 | 注册为系统登录项，切换后立即生效 | 关 |

前五项持久化在 `UserDefaults`（域 `com.matoah.token-gauge`），修改后立即生效并触发一次刷新；「登录时打开」通过 `SMAppService` 注册登录项，状态以系统登录项设置为准。

## 接口约定

`GET` 配置的 URL，请求头 `Authorization: <API Key>`，期望返回：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "limits": [
      { "type": "CREDIT_LIMIT", "unit": 3, "percentage": 56, "...": "..." },
      { "type": "CREDIT_LIMIT", "unit": 6, "percentage": 14, "...": "..." }
    ],
    "level": "lite"
  },
  "success": true
}
```

`data.limits` 中 `unit = 3` 为 5 小时用量，`unit = 6` 为周用量，取各自 `percentage`（四舍五入到整数）显示。

## 开发

- Swift Package 结构，源码在 `Sources/TokenGauge/`：
  - `AppMain.swift` 应用入口（`LSUIElement` 菜单栏应用）
  - `AppDelegate.swift` 菜单栏状态项、弹出菜单、配置窗口
  - `StatusItemView.swift` 两行用量显示（宽度按内容自适应）
  - `AppState.swift` 配置 + 定时查询状态机
  - `UsageService.swift` / `UsageModels.swift` HTTP 请求与解析
  - `ConfigView.swift` 配置界面
  - `LoginItem.swift` 「登录时打开」登录项注册（SMAppService）
- `scripts/build-app.sh [debug|release]`：编译 + 组装 `.app`（Info.plist、图标、ad-hoc 签名）
- `scripts/make-icon.sh`：由 `icon.svg` 生成 `AppIcon.icns`
