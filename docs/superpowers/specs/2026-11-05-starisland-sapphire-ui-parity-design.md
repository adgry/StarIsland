# 星岛 (`StarIsland` v2.0) — 100% 原版 UI 复刻与全付费功能真解锁架构规格书

- **日期**：2026-11-05
- **项目目录**：`/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland`
- **目标仓库**：`https://github.com/adgry/StarIsland`
- **发布版本**：`v2.0.0`（可从已安装的 `StarIsland` `v1.0.0` 平滑覆盖与自动升级）
- **开源许可证**：GNU Affero General Public License v3.0 (`AGPL-3.0`)

---

## 1. 背景与核心目标

在完成自研洁净室架构 `StarIsland` `v1.0.0` 后，用户进一步明确要求：
> **「界面也要完全模仿他来做，不只是功能，我希望界面能做到 100% 模仿」**，并在方案选择中确认采用 **直接基于 `Sapphire` 开源 `AGPLv3` 真实 UI 底座深度改造** 的路径。

本阶段交付必须同时满足以下六大硬性指标：
1. **100.0% 原版 UI、动效与素材一致性**：原样保留 `Sapphire` 全部视觉层——`NotchMorphEngine` 物理刘海/悬浮岛贝塞尔形变舞台、卫星气泡、250pt 毛玻璃侧边栏 + 6 大分组 41 个设置子面板、可视化拖拽布局编辑器、14 段 `.mp4`/`.mov` 演示视频、靛蓝渐变首次启动向导及全部原生小组件/实时活动/锁屏天气音乐与系统 HUD。
2. **零付费墙与 46 项 Pro/Ultra 特性永久全解锁**：移除一切付费订阅拦截、灰显锁与推销步骤；侧边栏账户卡片展示「星岛旗舰版 · 全功能永久解锁」。
3. **35 个阉割模块（`Sapphire/Stubs/`）100% 真实功能补齐**：杜绝任何「当前构建版本未包含此功能」或空实现桩，接入经单元测试验证的真实业务逻辑（免 Key 体育 ESPN / 财经 Yahoo+Binance / 天气 OpenMeteo、多通道 AI 与圈选识屏 OCR、15 个系统与效率设置子面板及后台服务、Touch ID 应用锁、免装 App 手机扫码局域网双向快传）。
4. **四大原版 Bug 根治**：
   - 根治普通聊天数字（如 `yetone (#general, Text Channels) 3068`）被误判为验证码并无限重弹；
   - 根治「本地网络」点击授权无响应、无法进入 macOS「隐私与安全性 → 本地网络」列表；
   - 根治「自动化」点击授权强行拉起受限 `Music.app` 弹出 Finder「应用程序“音乐.app”已不能再打开」报错；
   - 根治特权辅助工具 `SAP-H1`（`辅助工具无法启动`）签名拒绝与引导向导卡死。
5. **100% 原生简体中文体验**：全界面、提示文案、更新器及设置搜索关键词均为自然地道的简体中文。
6. **本地安装与 `adgry/StarIsland` 自动更新闭环**：使用本机有效 `Apple Development` 证书完成内外双层代码签名，部署至 `/Applications/StarIsland.app` 实测运行，并将源码与 `v2.0.0` 安装包（`StarIsland-arm64.zip` + SHA-256 摘要）发布至 `https://github.com/adgry/StarIsland`，软件内更新地址指向 `adgry/StarIsland`。

---

## 2. 工程整合与品牌重塑架构

### 2.1 仓库目录融合策略
- 将已完成简体中文汉化的 `Sapphire-main` 完整 Xcode 工程（`Sapphire.xcodeproj`、`Sapphire/`、`SapphireTests/`、`com.shariq.sapphireHelper/`、`Nearby/`、`ObjC/`、`PrivateHeaders/`、`ProtobufGenerated/`、`SystemSounds/`、`Volume/`、`Assets/`、`LICENSE` 等）迁入 `/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland` 仓库根目录，替换 `v1.0.0` 的旧独立 `App/` 与 `Helper/` 目录。
- 利用 Xcode 16 `PBXFileSystemSynchronizedRootGroup` 同步目录特性，在 `Sapphire/Stubs/` 与 `Sapphire/StarIslandEngines/` 中直接承载全部解锁引擎实现，无需脆弱手工维护单文件 `PBXBuildFile` ID。
- 保留 `docs/superpowers/` 设计规格与实施计划记录，保留 `AGPLv3` `LICENSE` 与开源声明。

### 2.2 品牌与签名标识规范
| 项目 | 设定值 |
| :--- | :--- |
| 应用包名与可执行名 | `StarIsland.app`（`Contents/MacOS/StarIsland`） |
| 应用中文显示名 (`CFBundleDisplayName` / `CFBundleName`) | `星岛` |
| 主应用 Bundle Identifier | `com.adgry.starisland` |
| 特权辅助工具标识 (`Label` / `MachServices` / `--identifier`) | `com.adgry.starisland.helper` |
| 特权辅助工具 LaunchDaemon Plist | `com.adgry.starisland.helper.plist`（`AssociatedBundleIdentifiers` = `["com.adgry.starisland"]`） |
| 单元测试 Target Bundle ID | `com.adgry.starisland.tests`（`TEST_HOST` 指向 `StarIsland.app/Contents/MacOS/StarIsland`） |
| 本机签名身份 | 自动检测本机钥匙串有效 `Apple Development` 证书（`5DAFE276C2625083506C9E10ACC1B5D2AC5A4418`，Team `267X356H4D`），CI 无证书环境回退 Ad-Hoc `-` |
| 版本号 | `MARKETING_VERSION = 2.0.0`，`CURRENT_PROJECT_VERSION = 20000` |
| 软件内自动更新仓库 | `adgry/StarIsland`，识别 `StarIsland-arm64.zip` |

---

## 3. 四大原版 Bug 根因与根治方案

### 3.1 验证码连弹误报根治（`VerificationCodeDetector` + `SmartInboxFeatures` + `NotificationManager`）
- **根因**：原版 `Stubs/VerificationCodeDetector.swift` 对任意通知直接跑 `\b\d{4,8}\b` 正则，无任何语义上下文词校验；且 `Stubs/SmartInboxFeatures.swift` 中 `hasConsumedOTP(_:)` 恒返回 `false`、`consumeOTP(_:)` 为空实现，导致普通群聊数字被反复当作验证码弹出。
- **修复设计**：
  1. **双因子语义校验**：在 `VerificationCodeDetector.find(in:)` 中，要求文本必须包含中英文验证码语义触发词（`验证码`、`校验码`、`动态码`、`安全码`、`确认码`、`登录码`、`授权码`、`提取码`、`verification`、`code`、`otp`、`passcode`、`2fa`、`pin`、`one-time`），同时过滤纯年份（`1990..2039`）、时间片段（`12:30`）、金额/百分比（带 `¥`、`$`、`元`、`%` 前后缀）、Discord/群频道标签（`#general`）及订单尾号。
  2. **SHA-256 持久化消费去重**：`SmartInboxMonitor.shared` 在 `~/Library/Application Support/StarIsland/consumed_otp_hashes.json` 原子持久化已消费/已关闭验证码的 SHA-256 摘要（保留最近 500 条），`presentOTP` 若命中 `hasConsumedOTP` 直接忽略；用户复制或关闭后立即写入消费记录并清空 `latestOTP`。
  3. **启动历史通知水位线保护**：在 `NotificationManager.setupDatabaseConnection()` 中，若通知数据库当前无历史记录或首次初始化，将 `lastNotificationDate` 设为不早于 `Date().timeIntervalSinceReferenceDate - 5.0`，杜绝冷启动回放历史通知。

### 3.2 本地网络权限点击无反应修复（`PermissionsManager` + `Info.plist` + Apple Development 签名）
- **根因**：
  1. macOS 15+ (`Sequoia` / `Tahoe`) 的 `nehelper` / `TCC` 子系统对无证书 Ad-Hoc (`--sign -`) 签名应用不分配稳定的本地网络 TCC 身份，导致系统既不弹授权窗，也不会把应用写入「系统设置 → 隐私与安全性 → 本地网络」列表；
  2. `LocalNetworkAccessProbe` 在用户点击「授权」后若 2.5s 内未收到明确结果或返回 `.undetermined`，UI 无任何跳转或提示。
- **修复设计**：
  1. 使用本机钥匙串真实的 `Apple Development` 证书签名 `StarIsland.app`，赋予稳定的 Apple Team ID (`267X356H4D`) 与代码身份；
  2. `Info.plist` 的 `NSBonjourServices` 同时声明 `_starisland._tcp`、`_sapphirecont._tcp`、`_sapphire-lnp._tcp`、`_http._tcp`；
  3. 在 `PermissionsManager.probeLocalNetwork(triggeredByUser: true)` 中，立即发起 UDP 多播 + Bonjour 监听与浏览触发系统原生弹窗；若此前已请求过权限或探测在 3.5 秒内仍处于等待/受阻状态，自动打开 `SystemPreferencesPane.localNetwork` 供用户一键开关，并实时刷新状态。

### 3.3 自动化权限弹出「应用程序“音乐.app”已不能再打开」修复（`PermissionsManager`）
- **根因**：`PermissionsManager.triggerAutomationPermissionRequest()` 遍历 `Music`、`Spotify`、`System Events` 时调用 `launchAutomationTarget` 执行 `NSWorkspace.shared.openApplication(at:)` 强行启动未运行的 `Music.app`；当用户系统禁用或限制了 `Music.app` 时，Finder 立即弹出错误提示框。
- **修复设计**：
  1. 修改 `launchAutomationTarget(_:)`：**绝不强行启动未运行的第三方或媒体应用（`com.apple.Music`、`com.spotify.client`）**；仅当目标应用已在运行（`!NSRunningApplication.runningApplications(withBundleIdentifier:).isEmpty`）时才纳入本次 `AEDeterminePermissionToAutomateTarget` 请求；
  2. 对后台无界面系统服务 `com.apple.systemevents`（`System Events.app`），若未运行则静默后台启动并请求 Apple Events 授权，从而确保应用立即注册进「系统设置 → 隐私与安全性 → 自动化」列表，且零弹窗报错。

### 3.4 特权辅助服务 `SAP-H1` 根治（`CodesignCheck` + `HelperManager` + `OnboardingView`）
- **根因**：`SMAppService.daemon` 要求主应用与内嵌守护进程具备匹配的签名标识与证书链，原版硬编码 `com.cshariq.sapphire` / `com.shariq.sapphireHelper` 且以 Ad-Hoc 签名，被 `launchd` 拦截产生 `SAP-H1`，并在首次启动向导阻塞用户。
- **修复设计**：
  1. 全局同步更新辅助工具标识：`CodesignCheck`、`HelperManager`、`Constants.swift`、`XPC` 连接名及 `com.adgry.starisland.helper.plist` 统一使用 `com.adgry.starisland` 与 `com.adgry.starisland.helper`；
  2. 构建脚本先以同一张 `Apple Development` 证书对内嵌 `com.shariq.sapphireHelper` 二进制附加 `--identifier com.adgry.starisland.helper` 与 entitlements 签名，再对外层 `StarIsland.app` 签名；
  3. 在 `OnboardingView` 的 `HelperInstallationStepView` 中，把「暂时跳过」升级为清晰可见的次级胶囊按钮，并在无电池桌面 Mac（如 Mac mini / Mac Studio）上提示「台式 Mac 无需电池充电限制，可直接继续使用全部灵动岛功能」，绝不阻塞引导流程。

---

## 4. 全量付费功能解锁与 35 个 `Stubs/` 模块实现设计

### 4.1 订阅与门控层（零付费墙）
- **`SubscriptionCore.swift` & `BetaEntitlementValidator.swift`**：
  - `SubscriptionAccess.hasAccess(to:)` 对全部 46 个 `AppFeature` 恒返回 `true`；`resolvedTier()` 恒返回 `.ultra`；`intelligenceDailyRunLimit()` 返回 `Int.max`。
  - `SubscriptionManager.shared` 默认持有 `SubscriptionEntitlements(tier: .ultra, features: Set(AppFeature.allCases), expiresAt: nil)`，`isSignedIn = true`，`userDisplayName = "星岛旗舰版"`，`userInitials = "星"`，`tierLabel = "全功能永久解锁"`，`tierGradientColors = [.cyan, .indigo]`，`hasBetaSoftwareAccess = true`。
  - `FeatureGate.shared.require(_:message:)` 恒返回 `true`，绝不发送 `.subscriptionPaywallRequested` 通知。
- **`PremiumFeatureKit.swift`**：
  - `PremiumFeatureView.body` 直接返回 `content`（彻底移除原版 `.disabled(true).opacity(0.45)`）；
  - `WidgetType.isPremiumLocked` 与 `LiveActivityType.isPremiumLocked` 恒为 `false`。
- **`OnboardingView.swift`**：
  - 从向导步骤流中跳过 `.subscriptionOverview` 付费推销步（由 `.lockScreenSetup` 直接进入 `.finish`），保留其余全部原版引导体验。
- **`AccountSettingsView`（`PrivateViews.swift`）**：
  - 采用原版 `SettingsComponents` 毛玻璃卡片规范，展示「星岛 StarIsland 旗舰版 · 全部 46 项高级特性已永久解锁」徽章、当前版本状态、一键检查更新按钮及 `adgry/StarIsland` GitHub 仓库入口。

### 4.2 免 Key 体育与财经小组件、实时活动及设置页
- **体育（`SportsAPIService.swift`、`SportsWidgetView.swift`、`SportsPlayerView.swift`、`SportLayoutRegistry.swift`、`SportsSettingsView`）**：
  - 接入 **ESPN 公开 Scoreboard API**（`site.api.espn.com/apis/site/v2/sports/.../scoreboard`），支持 NBA、英超（EPL）、欧冠（UCL）、NFL、MLB、NHL、F1 等联赛实时比分、比赛状态/节数时钟、队标异步缓存及最新赛况解说摘要；
  - 实现灵动岛缩略小组件 `SportsWidgetView`、展开详情 `SportsPlayerView`、灵动岛左右翼实时活动 `SportsLiveActivityView` 以及可增删关注球队/联赛的 `SportsSettingsView`。
- **财经（`FinanceAPIService.swift`、`FinanceWidgetView.swift`、`FinancePlayerView.swift`、`FinanceSettingsView`）**：
  - 接入 **Yahoo Finance v8 Chart API + Binance 24hr Ticker API**，无需 API Key 实时获取美股/港股/A 股指数（如 `AAPL`、`NVDA`、`TSLA`、`SPY`）与主流加密货币（`BTC-USD`、`ETH-USD`、`SOL-USD`）最新价、涨跌额、涨跌幅与分时折线序列；
  - 实现灵动岛行情小组件 `FinanceWidgetView`、带 SwiftUI 分时走势图的展开视图 `FinancePlayerView`、左右翼实时活动 `FinanceLiveActivityView` 以及可自定义自选标的的 `FinanceSettingsView`。

### 4.3 多通道智能助手、Blip 工作台与画圈搜屏 OCR
- **模型与配置层（`IntelligenceModels.swift`、`MonitoringCore.swift`）**：
  - 完整支持 `Gemini`、`OpenAI`（兼容 DeepSeek / 通义千问 / OpenRouter 自定义 Base URL）与本地免 Key `Ollama`（`http://127.0.0.1:11434`）后端，API Key 安全存取自 `SettingsModel` / Keychain；
  - 实现原版风格 `IntelligenceSettingsView`（提供商切换、API Key / Base URL / 模型名配置、连通性测试及本地屏幕记忆摘要面板）。
- **灵动岛交互层（`IntelligenceNotchViewModel.swift`、`IntelligenceNotchView.swift`、`BlipHubView.swift`、`GeminiLiveManagerStub.swift`）**：
  - `IntelligenceNotchViewModel` 与 `IntelligenceNotchView` 提供真实多轮流式问答、快捷提示词（总结剪贴板、润色文本、解释代码、中英互译）与执行步骤日志；
  - `BlipHubView` 提供灵动岛快捷 AI 指令中枢与剪贴板/当前窗口上下文一键提问。
- **画圈搜屏与离线识屏（`CircleToSearchManager.swift`、`CircleToSearchResultsView.swift`、`ScreenPerception`）**：
  - 监听 `.sapphireOpenCircleToSearch` 与快捷键，呼出全屏十字框选遮罩截取指定区域，调用 macOS 原生 `VNRecognizeTextRequest`（`zh-Hans` + `en-US` `.accurate`）提取文字，在灵动岛 `CircleToSearchResultsView` 展示识别文本，支持一键复制、翻译及发送给 AI 深度解答。

### 4.4 15 个高级系统与效率模块（`PremiumFeatureModels` + `PremiumFeatureManagers` + `PremiumFeatureViews`）
- **后台管理器真实化（`PremiumFeatureManagers.swift` & `PremiumFeatureModels.swift`）**：
  - **鼠标与键盘增强**：`MouseControlManager`（平滑滚轮插值、仅反转鼠标滚轮保留触控板自然滚动）、`FocusFollowsMouseManager`（鼠标悬停自动激活窗口）、`ExtraClickFilterManager`（微动双击防抖过滤）、`KeyboardDebounceManager`（键盘连击防抖）、`SuperKeyManager`（Caps Lock / 修饰键增强）、`SystemEnhanceQuitProtection`（长按 `⌘Q` 确认防误退及白名单规则）、`FinderCutPasteManager`（Finder 内 `⌘X` / `⌘V` 剪切移动文件）、`SystemEnhanceGreenMaximize`（点击窗口左上角绿色按钮桌面最大化而非进入独立全屏空间）、`SystemEnhanceAutoQuit`（关闭最后窗口自动退出空闲应用）；
  - **效率工具**：`CaretPositionTracker`（Accessibility 光标坐标追踪）、`EmojiPicker` / `SnippetManager`（输入光标旁快捷表情与短语面板）、`ClipboardURLCleaner`（自动剥离 `utm_*`、`spm`、`fbclid` 等追踪参数且保留正常业务参数如 `from`）、`ClipboardItemThumbnailView`（真实渲染剪贴板图片/文件缩略图）；
  - **硬件、存储与安装包**：`WiFiStatusMonitor`（CoreWLAN 实时连接与 SSID 状态）、`SystemPowerReading` & `PowerSplitBar` & `StatsManager.adapterSensorPower`（IOKit 电源瓦数读取与分流条）、`DMGInstallerManager`（打开 `.dmg` 自动挂载探测 `.app` 并提供拖拽拷入 `/Applications` 与卸载清理）、`StorageSpaceMapSnapshot`（真实异步目录体积扫描与占比快照）、`DockLayout`（Dock `com.apple.dock` 布局备份导出与一键恢复）、`MenuBarProfileEngine`（多显示器/专注模式菜单栏配置管理）、`QuarantineAttribute`（安全扩展属性同步）。
- **15 个设置子视图与详情视图全量补齐（`PremiumFeatureViews.swift`）**：
  - 使用原版 `SettingsComponents`（`SettingsPageHeader`、`SettingsCard`、`IconToggleRow`、`InfoContainer` 等）完整实现：`KeyboardShortcutsSettingsView`、`ContinuitySettingsView`、`EmojiSettingsView`、`MouseSettingsView`、`MonitoringSettingsView`、`ArchivesAndDMGInstallerSettingsView`、`AppLockSettingsView`、`DockLayoutsSettingsView`、`MediaOptimizerSettingsView`（接入 `sips` / `AVAssetExportSession` 真实无损/有损图片视频体积压缩）、`SEQuitProtectionRulesView`、`StorageWorkspaceView`、`StorageDetailView`、`StorageWidgetView`、`EightDAudioView`（实时 8D 环绕声轨道控制与声场可视化）、`SurroundAudioView`（空间环绕声增强控制）。

### 4.5 应用锁与跨端局域网互通
- **应用锁与专注遮罩（`AppLockManager.swift`、`AppLockOverlayView.swift`、`AppProtectionCore.swift`）**：
  - `AppLockManager` 接入 `LocalAuthentication`（Touch ID / Apple Watch / 系统密码回退）及 SHA-256 独立应用锁密码校验，监听 `NSWorkspace.didActivateApplicationNotification`；
  - 当受保护应用激活时，`AppBlocker` 立即在对应窗口上方弹出全屏高斯的 `AppLockOverlayView` / `AppShieldView` 毛玻璃锁定面板，验证通过后放行，记录失败尝试时间与方式。
- **跨端局域网快传（`ContinuityCore.swift`）**：
  - 将 `ContinuityManager`、`ContinuityNotchDetailView` 与 `ContinuitySettingsView` 接入内置的 **局域网扫码免装 App Web 门户引擎**（`NWListener` HTTP 服务 + CoreImage 二维码生成 + 6 位常量时间校验动态配对码 + Bearer 会话令牌）：
  - 任何 iPhone 或 Android 手机无需安装客户端，直接用相机扫码输入 6 位配对码即可在响应式中文网页中完成：**手机⇄Mac 双向文件快传**、**双向剪贴板同步**与**远程控制 Mac 音乐播放/系统音量**，同时保留原版蓝牙邻近发现状态兼容。

---

## 5. 错误处理、安全性与测试验收

### 5.1 安全与稳定性边界
1. **无损系统还原**：鼠标滚轮、窗口行为或辅助事件监听（`CGEventTap`）仅在对应开关开启且具备辅助功能权限时按需挂载，关闭开关或退出应用时立即卸载监听，零残留系统状态污染。
2. **局域网门户鉴权**：所有 `/api/*` 接口强制校验一次性 6 位动态配对码签发的 256-bit 随机 Bearer 会话令牌，上传文件名严格剥离路径穿越字符（`..`、`/`、`\`），单文件限制 512 MB。
3. **自动更新校验**：`UpdateChecker` 强制 HTTPS 校验、Zip 炸弹与路径穿越预检、Bundle Identifier 一致性校验（`AppSecurityValidator`）及 SHA-256 摘要核对。

### 5.2 自动化测试与真机交付验收清单
1. **XCTest 单元与集成测试套件（`SapphireTests`）**：
   - `StarIslandUnlockTests`：验证全部 46 项 `AppFeature` 恒解锁、`SubscriptionManager` 处于 `.ultra`、`FeatureGate` 永不触发付费墙；
   - `StarIslandOTPFilterTests`：验证真实中英文短信验证码提取成功，验证 `yetone (#general, Text Channels) 3068`、年份 `2026`、时间 `14:30`、金额 `¥3068` 均返回 `nil`，验证 `SmartInboxMonitor` SHA-256 消费后持久化不重弹；
   - `StarIslandWidgetsAPITests`：验证 ESPN 赛事 JSON 与 Yahoo Finance / Binance 行情 JSON 解码及异常降级；
   - `StarIslandPermissionsAndUpdateTests`：验证自动化权限策略不强拉未运行的 `Music.app`、验证 `UpdateChecker` 指向 `adgry/StarIsland` 且正确判定 `StarIsland-arm64.zip` 版本升级（如 `2.0.0` > `1.0.0`、`2.0.1` > `2.0.0`）。
2. **Release 编译与签名校验**：
   - `xcodebuild -project Sapphire.xcodeproj -scheme Sapphire -configuration Release -destination "platform=macOS,arch=arm64" build` 零错误通过；
   - 使用本机 `Apple Development` 证书完成内外双层签名，`codesign --verify --deep --strict --verbose=2` 校验零报错。
3. **本机实装与云端发布**：
   - 部署至 `/Applications/StarIsland.app`，实际启动进程并验证窗口渲染、进程存活且 `~/Library/Logs/DiagnosticReports` 零崩溃；
   - 推送代码至 `https://github.com/adgry/StarIsland` `main` 分支，创建并验证 GitHub Release `v2.0.0`（含 `StarIsland-arm64.zip` 与 `StarIsland-arm64.zip.sha256`）。
