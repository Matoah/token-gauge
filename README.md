# T·量

macOS 菜单栏 Token 用量监视器。应用常驻系统菜单栏（无 Dock 图标），按平台轮播显示用量：

- **智谱AI**（配额型）：上下两行，上为 5 小时用量（接口返回 `unit = 3` 的条目）、下为周用量（`unit = 6`），每行「彩点 + 百分比」
- **DeepSeek**（余额型）：单行「彩点 + 账户余额」（如 `¥25.91`）
- 各启用平台按全局轮询间隔轮播（0 = 不轮询，固定显示第一个启用平台）；状态项宽度固定为最宽帧，切帧时不挤动相邻图标；轮播仅切换显示，不触发网络请求
- 显示模式（可在配置中切换）：普通模式（默认）为「图标 + 彩点 + 数值」；简约模式仅显示图标，图标按该平台彩点配色渲染为单色剪影（智谱AI 取 5 小时额度配色、DeepSeek 取余额配色），详细数值见下拉「用量详情」
- 用量显示方案（可在配置中切换），决定智谱AI 菜单栏与用量详情中百分比数字的含义：已使用百分比（默认）/ 剩余百分比（超出额度时显示 0）；简约模式下菜单栏无数字，仅作用于用量详情
- 颜色显示方案（可在配置中切换），决定智谱AI 菜单栏圆点与用量详情百分比的配色，两者始终保持同色（配色始终基于实际用量，与所显数字方案无关）：
  - 按用量显示（默认）：按已使用百分比配色，`[0%, 30%]` 绿色；`(30%, 70%]` 蓝色；`(70%, 100%]` 红色
  - 按进度显示：按当前消耗速率推算整个周期结束时的用量配色，`[0%, 80%]` 绿色；`(80%, 100%]` 蓝色；`(100%, ∞)` 红色（需接口返回重置时间）；窗口已进行时间不足其时长 10% 时按 10% 计入速率估算，避免初期短时爆发消耗被外推放大成超额
- DeepSeek 余额配色（低余额阈值三档）：余额 ≤ 阈值 红色；`(阈值, 3×阈值]` 蓝色；其余绿色。阈值默认 `¥10`，设为 `0` 表示仅余额 ≤ 0 时红色

## 使用

```bash
bash scripts/build-app.sh        # 编译并打包为 build/T·量.app
open "build/T·量.app"
```

点击菜单栏中的用量显示，弹出菜单：

- **用量详情**：按平台分页签（下划线式，图标 + 平台名；仅启用一个平台时隐藏页签栏，无启用平台显示占位）：智谱AI 页展示各额度百分比、积分使用与重置时间，DeepSeek 页展示余额及赠送 / 充值拆分；点击页签切换，默认选中第一个启用平台；高度固定为最高页内容，切页签时菜单高度不跳动
- **打开T·量**：打开配置窗口
- **退出**：退出应用

## 配置项

平台配置（每个平台一个账号位，含「启用此平台」开关，停用后菜单栏隐藏对应帧、不清空密钥）：

| 配置 | 平台 | 说明 | 默认值 |
| --- | --- | --- | --- |
| 请求地址 | 智谱AI | 用量接口的完整 URL | 空 |
| API Key | 智谱AI | 作为 `Authorization` 请求头发送 | 空（不发送） |
| 请求地址 | DeepSeek | 余额接口的完整 URL | `https://api.deepseek.com/user/balance` |
| API Key | DeepSeek | 作为 `Authorization: Bearer <API Key>` 请求头发送 | 空 |
| 低余额阈值 | DeepSeek | 余额配色分档，见上文说明 | `10` |

全局配置：

| 配置 | 说明 | 默认值 |
| --- | --- | --- |
| 超时时间(秒) | 请求超时（两平台共用） | 10 |
| 自动查询间隔(分钟) | 定时刷新间隔，`0` 表示不自动查询 | 5 |
| 轮询间隔(秒) | 菜单栏平台帧轮播间隔，`0` 表示不轮询 | 5 |
| 显示模式 | 普通模式：图标 + 彩点 + 数值；简约模式：仅图标，颜色同各平台彩点 | 普通模式 |
| 颜色显示方案 | 按用量 / 按进度配色，见上文说明 | 按用量显示 |
| 用量显示方案 | 百分比数字显示已使用或剩余百分比 | 已使用百分比 |
| 登录时打开 | 注册为系统登录项，切换后立即生效 | 关 |

以上配置持久化在 `UserDefaults`（域 `com.matoah.token-gauge`），修改后立即生效并触发一次刷新；「登录时打开」通过 `SMAppService` 注册登录项，状态以系统登录项设置为准。旧版单平台的 `config.baseURL` / `config.apiKey` 在首次启动时自动迁入智谱AI 平台。

各平台独立查询、独立展示更新时间与错误，互不影响；出错时保留上次成功数据，菜单栏显示 `--` 占位。

## 接口约定

### 智谱AI（用量）

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

### DeepSeek（余额）

`GET` 配置的 URL（默认 `https://api.deepseek.com/user/balance`），请求头 `Authorization: Bearer <API Key>`，期望返回：

```json
{
  "is_available": true,
  "balance_infos": [
    {
      "currency": "CNY",
      "total_balance": "25.91",
      "granted_balance": "0.00",
      "topped_up_balance": "25.91"
    }
  ]
}
```

取 `currency = CNY` 的条目（防御性回退第一条），标题行显示 `total_balance`，详情拆分 `granted_balance`（赠送）/ `topped_up_balance`（充值）；`is_available = false` 时详情增加红色「状态：不可用」。

## 开发

- Swift Package 结构，源码在 `Sources/TokenGauge/`：
  - `AppMain.swift` 应用入口（`LSUIElement` 菜单栏应用）
  - `AppDelegate.swift` 菜单栏状态项（轮播固定最大宽度渲染）、弹出菜单、配置窗口
  - `StatusItemView.swift` 单帧渲染（普通模式「图标 + 彩点 + 数值」、简约模式单色剪影图标）与配色取值
  - `AppState.swift` 配置 + 分平台查询状态机 + 轮播定时器
  - `UsageService.swift` / `UsageModels.swift` HTTP 请求与解析（智谱用量、DeepSeek 余额）
  - `Config.swift` 多平台配置模型与旧键迁移
  - `ConfigView.swift` 配置界面（平台、查询、通用设置）
  - `PlatformIcon.swift` 平台图标加载与单色剪影着色
  - `LoginItem.swift` 「登录时打开」登录项注册（SMAppService）
- `Assets/platform-icons/` 内置平台官方图标 PNG，由 `build-app.sh` 复制进 `.app` 的 `Contents/Resources/`
- `scripts/build-app.sh [debug|release]`：编译 + 组装 `.app`（Info.plist、图标、ad-hoc 签名）
- `scripts/make-icon.sh`：由 `icon.svg` 生成 `AppIcon.icns`
