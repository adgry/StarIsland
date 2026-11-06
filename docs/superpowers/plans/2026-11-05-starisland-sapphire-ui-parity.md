# 星岛 (StarIsland v2.0) 100% 原版 UI 复刻与全功能解锁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于已汉化 `Sapphire` 开源 `AGPLv3` UI 工程 100% 原样保留全部界面与形变动效，替换全部 35 个 `Sapphire/Stubs/` 阉割模块为真实全解锁实现，根治四大原版 Bug，安装至 `/Applications/StarIsland.app` 并发布 `v2.0.0` 至 `adgry/StarIsland`。

**Architecture:** 将 `Sapphire-main` Xcode 16 同步目录工程迁入 `StarIsland` 仓库主干，重塑主包为 `StarIsland.app`（`com.adgry.starisland`）与特权服务 `com.adgry.starisland.helper`，通过钥匙串有效 `Apple Development` 证书完成内外双层签名；在 `Sapphire/Stubs/` 与 `Sapphire/StarIslandEngines/` 内把订阅门控、体育/财经免 Key 数据源、多通道 AI + Vision 识屏、15 个高级设置页及后台增强管理器、Touch ID 应用锁与局域网扫码双向快传全部替换为真实实现。

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, Network, LocalAuthentication, Vision, CoreWLAN, CoreAudio/AVFoundation, SQLite, XCTest (`xcodebuild`).

**Spec:** `docs/superpowers/specs/2026-11-05-starisland-sapphire-ui-parity-design.md`

## Global Constraints

- 主应用包名 `StarIsland.app`（显示名 `星岛`），Bundle ID `com.adgry.starisland`；辅助工具标识 `com.adgry.starisland.helper`，LaunchDaemon plist `com.adgry.starisland.helper.plist`。
- 版本号 `MARKETING_VERSION = 2.0.0`，`CURRENT_PROJECT_VERSION = 20000`；保留 GNU `AGPL-3.0` `LICENSE`。
- 全部 46 项 `AppFeature` 恒返回 `true`（`SubscriptionTier.ultra`），`PremiumFeatureView` 原样渲染 `content`（严禁 `.disabled(true)` 或 `.opacity(0.45)`），零付费墙弹窗。
- 全界面、报错与门户 100% 简体中文，严禁残留 `当前构建版本未包含` 占位文案。
- 软件内更新绑定 `adgry/StarIsland`，识别 `StarIsland-arm64.zip` 并按标准 SemVer 比较版本。

## Review Focus

- 普通群聊数字通知（如 `"yetone (#general, Text Channels) 3068"`、`"会议时间 14:30"`、`"2026 年报"`、`"消费 ¥3068"`）必须返回 `VerificationCodeDetector.find(in:) == nil`。
- 自动化权限请求（`PermissionsManager.launchAutomationTarget`）绝不能调用 `openApplication` 强拉未运行的 `com.apple.Music` 或 `com.spotify.client`，仅静默唤醒 `com.apple.systemevents`。
- 版本号比较（`SapphireVersionOrdering.isNewer`）必须遵循标准 SemVer（如 `"2.10.0"` 新于 `"2.2.0"`，`"2.0.0"` 新于 `"1.0.0"`）。
- `ClipboardURLCleaner.cleanIfEnabled` 剥离 `utm_*`、`spm`、`fbclid` 等追踪参数时，必须保留合法业务参数 `from`（如 `?from=search&utm_source=x` -> `?from=search`）。
- 局域网快传门户 `/api/upload` 必须净化文件名路径穿越字符（`../evil.sh` -> `evil.sh`）并强制校验 Bearer 令牌。

---

### Task 1: 工程底座迁入、品牌重塑、四大 Bug 修复与更新器绑定

**Files:**
- Modify: `Sapphire.xcodeproj/project.pbxproj`
- Modify: `Sapphire/App/Info.plist`, `Sapphire/App/HelperManager.swift`, `Sapphire/App/XPCClient.swift`, `Sapphire/App/PermissionsManager.swift`, `Sapphire/App/OnboardingView.swift`
- Modify: `Sapphire/Services/Miscellaneous/NotificationManager.swift`, `Sapphire/App Settings/UpdateChecker.swift`
- Modify: `com.shariq.sapphireHelper/Constants.swift`, `com.shariq.sapphireHelper/CodesignCheckError.swift`, `com.shariq.sapphireHelper/Helper.swift`, `com.shariq.sapphireHelper/Info.plist`, `com.shariq.sapphireHelper/com.adgry.starisland.helper.plist`, `SapphireHelper/Info.plist`
- Modify: `scripts/release.sh`, `.gitignore`
- Test: `SapphireTests/StarIslandCoreFixesTests.swift`

**Interfaces:**
- Produces:
  - `SapphireVersionOrdering.isNewer(_ candidate: String, than current: String) -> Bool` (标准 SemVer)
  - `UpdateChecker.updateRepository == "adgry/StarIsland"`，支持 `StarIsland-arm64.zip`
  - `PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: String) -> Bool`（仅 `"com.apple.systemevents"` 返回 `true`）

- [ ] **Step 1: 迁入 `Sapphire-main` 工程骨架并在 `SapphireTests/StarIslandCoreFixesTests.swift` 编写失败测试**
  断言：`UpdateChecker.updateRepository == "adgry/StarIsland"`、`SapphireVersionOrdering.isNewer("2.10.0", than: "2.2.0") == true`、`SapphireVersionOrdering.isNewer("2.0.0", than: "1.0.0") == true`、`PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: "com.apple.Music") == false`、`PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: "com.apple.systemevents") == true`、`HelperManager.shared.helperToolIdentifier == "com.adgry.starisland.helper"`。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandCoreFixesTests`
  Expected: FAIL（方法未定义或旧常量不匹配）。
- [ ] **Step 3: 实施品牌重塑、权限修复、Helper 签名标识对齐、向导去付费步与更新器 SemVer 改造**
  更新主应用 `PRODUCT_NAME = StarIsland`、`PRODUCT_BUNDLE_IDENTIFIER = com.adgry.starisland`、`MARKETING_VERSION = 2.0.0`；更新 Helper 标识为 `com.adgry.starisland.helper`；修复 `PermissionsManager` 本地网络跳转与自动化免强拉 `Music.app`；`NotificationManager` 冷启动水位线保护；`OnboardingView` 跳过 `.subscriptionOverview` 并提供清晰跳过辅助工具入口。
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandCoreFixesTests`
  Expected: PASS (`** TEST SUCCEEDED **`)，随后 `git commit`。

---

### Task 2: 旗舰版永久全解锁、双因子验证码语义识别与消费去重

**Files:**
- Modify: `Sapphire/Stubs/SubscriptionCore.swift`, `Sapphire/Stubs/PremiumFeatureKit.swift`, `Sapphire/Stubs/BetaEntitlementValidator.swift`, `Sapphire/Stubs/PrivateViews.swift`
- Modify: `Sapphire/Stubs/VerificationCodeDetector.swift`, `Sapphire/Stubs/SmartInboxFeatures.swift`
- Test: `SapphireTests/StarIslandUnlockAndOTPTests.swift`

**Interfaces:**
- Produces:
  - `SubscriptionAccess.hasAccess(to: AppFeature) -> Bool` (46 项恒为 `true`)
  - `VerificationCodeDetector.find(in text: String) -> String?` (双因子语义 + 排除规则)
  - `SmartInboxMonitor.shared.presentOTP(code:source:title:body:)`, `consumeOTP(_:)`, `hasConsumedOTP(_:) -> Bool` (SHA-256 持久化)

- [ ] **Step 1: 在 `SapphireTests/StarIslandUnlockAndOTPTests.swift` 编写失败测试**
  断言：`AppFeature.allCases` 全解锁、`SubscriptionManager.shared.activeTier == .ultra`、`FeatureGate.shared.require(.liveSports, message: "x") == true`；`VerificationCodeDetector.find(in: "yetone (#general, Text Channels) 3068") == nil`、年份/时间/金额为 `nil`、`"[阿里云] 您的验证码为 482910，5分钟内有效" == "482910"`；`SmartInboxMonitor` 调用 `consumeOTP("482910")` 后 `hasConsumedOTP("482910") == true`。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandUnlockAndOTPTests`
  Expected: FAIL。
- [ ] **Step 3: 实现全解锁门控、原版风格 `AccountSettingsView`、双因子验证码引擎与 SHA-256 去重**
  去除所有 `#if !SAPPHIRE_FULL_BUILD` 中的锁死逻辑；`PremiumFeatureView` 直接渲染 `content`；实现双因子语义检测与持久化去重存储。
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandUnlockAndOTPTests`
  Expected: PASS，随后 `git commit`。

---

### Task 3: 免 Key 体育（ESPN）与财经（Yahoo Finance + Binance）全套组件与设置页

**Files:**
- Modify: `Sapphire/Stubs/SportsAPIService.swift`, `Sapphire/Stubs/SportsWidgetView.swift`, `Sapphire/Stubs/SportsPlayerView.swift`, `Sapphire/Stubs/SportLayoutRegistry.swift`, `Sapphire/Stubs/SportsFinanceContentProvider.swift`
- Modify: `Sapphire/Stubs/FinanceAPIService.swift`, `Sapphire/Stubs/FinanceWidgetView.swift`, `Sapphire/Stubs/FinancePlayerView.swift`, `Sapphire/Stubs/PrivateViews.swift` (`SportsSettingsView`, `FinanceSettingsView`)
- Test: `SapphireTests/StarIslandWidgetsAPITests.swift`

**Interfaces:**
- Produces:
  - `SportsAPIService.parseESPNScoreboard(data: Data, leagueRoute: SportsLeagueRoute) -> [LiveSportsEvent]`
  - `FinanceAPIService.parseYahooChart(data: Data, fallbackSymbol: String) -> FinanceQuote?`
  - `FinanceAPIService.parseBinanceTicker(data: Data, displaySymbol: String) -> FinanceQuote?`

- [ ] **Step 1: 在 `SapphireTests/StarIslandWidgetsAPITests.swift` 编写失败测试**
  断言：样本 ESPN JSON 解析出主客队比分与状态；Yahoo Finance v8 JSON 与 Binance 24hr JSON 正确解析价格、涨跌幅与 `makePayload` 正负颜色标记；`SportLayoutRegistry.resolve(league:)` 正确区分篮球/足球/赛车。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandWidgetsAPITests`
  Expected: FAIL。
- [ ] **Step 3: 实现免 Key 体育与财经 API、灵动岛缩略/展开视图、实时活动左右翼视图及原版风格设置面板**
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandWidgetsAPITests`
  Expected: PASS，随后 `git commit`。

---

### Task 4: 多通道 AI 智能助手、Blip 工作台与离线画圈搜屏 OCR

**Files:**
- Modify: `Sapphire/Stubs/IntelligenceModels.swift`, `Sapphire/Stubs/IntelligenceNotchViewModel.swift`, `Sapphire/Stubs/IntelligenceNotchView.swift`, `Sapphire/Stubs/BlipHubView.swift`, `Sapphire/Stubs/MonitoringCore.swift`, `Sapphire/Stubs/GeminiLiveManagerStub.swift`
- Modify: `Sapphire/Stubs/CircleToSearchManager.swift`, `Sapphire/Stubs/CircleToSearchResultsView.swift`, `Sapphire/Stubs/PrivateViews.swift` (`ScreenPerception`)
- Test: `SapphireTests/StarIslandIntelligenceTests.swift`

**Interfaces:**
- Produces:
  - `LLMBackend` 支持 Gemini / OpenAI 兼容（DeepSeek、通义千问、OpenRouter）/ 本地 Ollama 请求构建与响应解析
  - `CircleToSearchManager.shared.recognizeText(in image: CGImage) async -> String`（Vision `zh-Hans` + `en-US`）

- [ ] **Step 1: 在 `SapphireTests/StarIslandIntelligenceTests.swift` 编写失败测试**
  断言：OpenAI 兼容与 Gemini 响应 JSON 解析准确；合成中文图像经 `CircleToSearchManager.shared.recognizeText(in:)` 识别出目标文字。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandIntelligenceTests`
  Expected: FAIL。
- [ ] **Step 3: 实现多模型流式/非流式对话引擎、`IntelligenceNotchView`、`BlipHubView`、`IntelligenceSettingsView` 及全屏框选 Vision OCR**
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandIntelligenceTests`
  Expected: PASS，随后 `git commit`。

---

### Task 5: 15 个高级系统与效率设置页、后台增强管理器与媒体/存储工具

**Files:**
- Modify: `Sapphire/Stubs/PremiumFeatureModels.swift`, `Sapphire/Stubs/PremiumFeatureManagers.swift`, `Sapphire/Stubs/PremiumFeatureViews.swift`
- Test: `SapphireTests/StarIslandPremiumManagersTests.swift`

**Interfaces:**
- Produces:
  - `ClipboardURLCleaner.cleanIfEnabled(_ raw: String) -> String?`（剥离 `utm_*`/`spm`/`fbclid` 等，保留 `from`）
  - `StorageSpaceMapSnapshot.make(...)` 真实分类体积快照
  - 全部 15 个设置/详情视图真实实现（零 `PremiumUnavailableView`）

- [ ] **Step 1: 在 `SapphireTests/StarIslandPremiumManagersTests.swift` 编写失败测试**
  断言：`ClipboardURLCleaner` 剥离追踪参数且保留 `?from=search`；鼠标/键盘防抖阈值与 `StorageSpaceMapSnapshot` 计算准确；源码扫描断言 `Sapphire/Stubs/` 不再包含 `"当前构建版本未包含"`。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandPremiumManagersTests`
  Expected: FAIL。
- [ ] **Step 3: 实现后台键鼠窗口增强管理器、WiFi/电源/存储/DMG/Dock 预设引擎及全部 15 个原版风格设置与音频视图**
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandPremiumManagersTests`
  Expected: PASS，随后 `git commit`。

---

### Task 6: Touch ID 应用锁遮罩与免装 App 扫码局域网双向快传

**Files:**
- Modify: `Sapphire/Stubs/AppLockManager.swift`, `Sapphire/Stubs/AppLockOverlayView.swift`, `Sapphire/Stubs/AppProtectionCore.swift`
- Modify: `Sapphire/Stubs/ContinuityCore.swift`, `Sapphire/StarIslandEngines/StarIslandLANPortalServer.swift`
- Test: `SapphireTests/StarIslandSecurityAndContinuityTests.swift`

**Interfaces:**
- Produces:
  - `AppLockManager` Touch ID / SHA-256 密码校验 + `AppBlocker` 窗口遮罩拦截
  - `StarIslandLANPortalServer.shared`（QR 码 + 6 位动态配对码 + Bearer 会话 + 文件名防穿越净化 `sanitizeUploadFilename(_:)`）接入 `ContinuityManager`、`ContinuityNotchDetailView` 与 `ContinuitySettingsView`

- [ ] **Step 1: 在 `SapphireTests/StarIslandSecurityAndContinuityTests.swift` 编写失败测试**
  断言：6 位动态配对码常量时间校验签发 Bearer 令牌、错误 PIN 拒绝、`sanitizeUploadFilename("../../etc/passwd") == "passwd"`；`AppLockManager` 密码回退校验与失败记录准确。
- [ ] **Step 2: 运行测试确认失败 (RED)**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandSecurityAndContinuityTests`
  Expected: FAIL。
- [ ] **Step 3: 实现 Touch ID 应用锁 + 毛玻璃遮罩面板，以及集成局域网扫码双向快传 Web 门户与灵动岛/设置交互页**
- [ ] **Step 4: 运行测试确认通过 (GREEN) 并提交**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64" -only-testing:SapphireTests/StarIslandSecurityAndContinuityTests`
  Expected: PASS，随后 `git commit`。

---

### Task 7: 全仓独立审查、Apple Development 签名构建、本地安装与 GitHub v2.0.0 发布

**Files:**
- Modify: `README.md`, `VERSION`, `.github/workflows/release.yml`

- [ ] **Step 1: 运行全套 XCTest 测试套件并通过独立代码审查子智能体全仓审计**
  Run: `xcodebuild test -project Sapphire.xcodeproj -scheme Sapphire -destination "platform=macOS,arch=arm64"`
  Expected: 0 failures；修复审查发现的所有 Critical / Important 项。
- [ ] **Step 2: 执行 Release 构建与本机 `Apple Development` 内外双层严格签名，安装至 `/Applications/StarIsland.app` 并启动实测**
  Run: `./scripts/release.sh 2.0.0 --build-only`（或分步构建签名），验证 `codesign --verify --deep --strict --verbose=2 "/Applications/StarIsland.app"` 退出码 `0`、进程存活且零崩溃日志。
- [ ] **Step 3: 推送源码至 `https://github.com/adgry/StarIsland` 并发布 `v2.0.0` Release（`StarIsland-arm64.zip` + `.sha256`）**
  Run: `gh release view v2.0.0 --repo adgry/StarIsland` 验证资产可下载且软件内更新接口在线。
