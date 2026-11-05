# 星岛（StarIsland）全功能原生 macOS 灵动岛系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans with parallel module waves to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从零构建并发布 100% 原生简体中文、零付费墙、包含全部核心灵动岛体验与 6 大高阶生产力模块（含原版全部 Pro/Ultra 功能真实实现）的独立 macOS 应用 **「星岛 StarIsland」**（`/Applications/StarIsland.app` 及 GitHub `adgry/StarIsland` `v1.0.0`）。

**Architecture:** 采用本地 Swift Package 微内核架构（`Packages/StarIslandKit`），由核心底座 `IslandCore` 向上承载 6 个零交叉依赖的独立业务模块（`MediaAudioKit`、`ProductivityKit`、`SystemEnhanceKit`、`HardwareCleanKit`、`LiveWidgetsKit`、`AIConnectKit`），最后由 `App/` 主壳层与 `Helper/` 特权守护进程统一组装打包为双层签名的 `StarIsland.app`。

**Tech Stack:** Swift 5.10 / 6.0、SwiftUI、AppKit、Combine、AVFoundation、Vision、ScreenCaptureKit、EventKit、CoreLocation、CoreBluetooth、LocalAuthentication、Network、Security、ServiceManagement、SQLite3 / JSON 原子持久化、XCTest。

**Spec:** `/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland/docs/superpowers/specs/2026-11-05-starisland-design.md`

## Global Constraints

- 最低系统版本：`macOS 14.0`（`.macOS(.v14)`），架构：`arm64`（Apple Silicon 原生）。
- 主应用 Bundle ID：`com.adgry.starisland`；特权守护进程 Bundle ID：`com.adgry.starisland.helper`；GitHub 远端仓库：`adgry/StarIsland`。
- 零商业订阅门控：严禁引入任何 `SubscriptionTier`、`Paywall` 或付费锁定逻辑，全部功能仅由用户本地开关与系统权限状态控制。
- 100% 原生简体中文：所有面向用户的界面文案、按钮、提示、菜单、权限说明与设置搜索关键词均为地道简体中文。
- 单文件职责清晰：每个 Swift 源文件聚焦单一职责，保持在 300～600 行以内；6 大业务模块仅依赖 `IslandCore`，互不直接 import。
- 严格 TDD：每个功能模块先在对应 `Tests/<Module>Tests/` 编写失败单测（RED），验证失败后再编写生产代码使单测通过（GREEN）。

## Review Focus

1. **普通群聊数字误触发验证码与重复弹窗**：Discord/微信群聊消息如 `"yetone (#general): 3068"` 或年份 `"2026"`、时间 `"14:30"`、价格 `"¥1299"` 绝不能识别为验证码；真实短信 `"【星岛】您的登录验证码为 839201，5分钟内有效"` 识别后再次收到相同指纹事件时必须被 `ConsumedEventStore` 拦截，绝不二次弹出。
2. **密码管理器隐私剪贴板泄露与脏追踪链接**：包含 `org.nspasteboard.ConcealedType` / `org.nspasteboard.TransientType` 的剪贴板内容绝不能记入历史；带 `utm_source`、`fbclid`、`spm` 的 URL 必须保留正常业务查询参数并精准剥离追踪参数。
3. **本地网络权限错误码误判**：`kDNSServiceErr_NoAuth (-65555)` 属于配置/未决状态而非用户拒绝，仅 `kDNSServiceErr_PolicyDenied (-65570)` 可判定为 `.denied`。
4. **系统级状态变更崩溃残留**：电池充电抑制、风扇手动转速、专注模式 hosts 屏蔽写入 `MutationJournal` 后，若上次会话未干净退出，启动恢复逻辑必须精准识别待回滚记录并清理已恢复项。
5. **局域网跨端互联未授权访问与路径穿越**：未携带有效 6 位配对会话令牌的 HTTP/WebSocket 请求必须返回 `401 Unauthorized`；上传文件名包含 `../` 或绝对路径分隔符时必须清洗为安全纯文件名，严禁越界写入。

---

### Task 1: `StarIslandKit` 工程骨架与 `IslandCore` 微内核底座

**Files:**
- Create: `Packages/StarIslandKit/Package.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/IslandGeometry.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/IslandStateMachine.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/ConsumedEventStore.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/MutationJournal.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/SettingsStore.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/PermissionsCenter.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/SelfUpdater.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/ServiceProtocols.swift`
- Create: `Packages/StarIslandKit/Sources/IslandCore/IslandWindowController.swift`
- Create: `Packages/StarIslandKit/Sources/{MediaAudioKit,ProductivityKit,SystemEnhanceKit,HardwareCleanKit,LiveWidgetsKit,AIConnectKit}/ModuleExports.swift`
- Test: `Packages/StarIslandKit/Tests/IslandCoreTests/IslandCoreTests.swift`

**Interfaces:**
- Produces:
  - `public enum IslandDisplayState: String, Equatable, Sendable { case compact, pill, peek, expanded, alertHUD }`
  - `public enum IslandTab: String, CaseIterable, Identifiable, Sendable { case nowPlaying, shelf, widgets, ai, connect }`
  - `public enum ActivityPriority: Int, Comparable, Sendable { case ambient = 20, ongoing = 40, interactive = 60, urgent = 80, critical = 100 }`
  - `public struct IslandActivityItem: Identifiable, Equatable, Sendable`
  - `@MainActor public final class IslandStateMachine: ObservableObject` (`submit(_:)`, `dismiss(id:)`, `setHovering(_:)`, `selectTab(_:)`, `isScreenLocked: Bool`)
  - `public final class ConsumedEventStore: @unchecked Sendable` (`init(fileURL:maxEntries:ttl:)`, `tryConsume(fingerprint:now:) -> Bool`, `hasConsumed(fingerprint:now:) -> Bool`)
  - `public final class MutationJournal: @unchecked Sendable` (`record(_:)`, `clear(_:)`, `pendingRecords() -> [MutationRecord]`)
  - `@MainActor public final class SettingsStore: ObservableObject` (`settings: StarIslandSettings`, `search(_ query: String) -> [SettingSearchItem]`, `exportJSON() throws -> Data`, `importJSON(_ data: Data) throws`)
  - `public enum LocalNetworkErrorPolicy` (`static func isPolicyDenied(dnsErrorCode: Int32) -> Bool`)
  - `@MainActor public final class PermissionsCenter: ObservableObject`
  - `public struct SemanticVersion: Comparable, Equatable, Sendable` & `@MainActor public final class SelfUpdater: ObservableObject`
  - `public protocol AIQueryServiceProtocol: Sendable` & `public protocol PrivilegedHelperProtocol: Sendable`
  - `@MainActor public final class IslandWindowController` (`IslandPanel` 非激活置顶宿主与刘海几何适配)

- [ ] **Step 1: 创建 `Package.swift`（声明 7 个库 Target 与 7 个 Test Target）及最小空编译占位，并在 `IslandCoreTests.swift` 编写失败单测**
  覆盖：刘海/无刘海几何计算、五态状态机优先级抢占与锁屏隐私过滤、`ConsumedEventStore` 原子消费与过期清理、`MutationJournal` 跨实例持久化恢复、`SettingsStore` 中文关键词检索与 JSON 导入导出、`LocalNetworkErrorPolicy`（`-65570` 为 `true`，`-65555` 为 `false`）、`SemanticVersion` 版本号排序。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `cd "/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland/Packages/StarIslandKit" && swift test --filter IslandCoreTests`
  Expected: FAIL（目标类型与方法尚未定义）
- [ ] **Step 3: 实现 `Sources/IslandCore/` 全部核心组件**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `cd "/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland/Packages/StarIslandKit" && swift test --filter IslandCoreTests`
  Expected: PASS（0 failures）
- [ ] **Step 5: 提交 Task 1**
  Commit: `feat(core): 完成 StarIslandKit 骨架与 IslandCore 微内核底座`

---

### Task 2: `MediaAudioKit`（媒体控制、LRCLIB 同步歌词、FFT 频谱、8D/环绕空间音效与系统 HUD）

**Files:**
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/NowPlayingModels.swift`
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/NowPlayingService.swift`
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/LyricsService.swift`
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/SpatialAudioProcessor.swift`
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/SystemHUDInterceptor.swift`
- Create: `Packages/StarIslandKit/Sources/MediaAudioKit/MediaIslandViews.swift`
- Test: `Packages/StarIslandKit/Tests/MediaAudioKitTests/MediaAudioKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`IslandStateMachine`, `SettingsStore`, `IslandActivityItem`, `ActivityPriority`)
- Produces:
  - `@MainActor public final class NowPlayingService: ObservableObject` (`currentTrack`, `togglePlayPause()`, `nextTrack()`, `previousTrack()`, `seek(to:)`)
  - `public struct TimedLyricLine: Equatable, Identifiable, Sendable` & `public enum LRCParser` (`static func parse(_ lrc: String) -> [TimedLyricLine]`, `static func activeLineIndex(in lines: [TimedLyricLine], at position: TimeInterval) -> Int?`)
  - `@MainActor public final class LyricsService: ObservableObject`
  - `public enum SpatialAudioMode: String, CaseIterable, Codable, Sendable { case off, surround, eightD }`
  - `public final class SpatialAudioProcessor` (`computeSpectrum(samples:bandCount:) -> [Float]`, `eightDListenerPosition(phase:radius:) -> (x: Float, y: Float, z: Float)`, `setMode(_:)`, `rotationHz: Double`)
  - `@MainActor public final class SystemHUDInterceptor: ObservableObject` (`presentHUD(kind:value:isMuted:)`)
  - `public struct NowPlayingIslandTabView: View` & `public struct MediaSettingsPaneView: View`

- [ ] **Step 1: 在 `MediaAudioKitTests.swift` 编写失败单测**
  覆盖：毫秒级 LRC 歌词解析与时间轴二分定位、静音与正弦波输入下的 32 段 FFT 频谱归一化、8D 环绕声圆周轨迹坐标周期连续性、媒体键 HUD 数值钳制与静音状态展示。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter MediaAudioKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `MediaAudioKit` 全部服务与 SwiftUI 灵动岛/设置视图**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter MediaAudioKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 2**

---

### Task 3: `ProductivityKit`（双因子智能验证码/快递、剪贴板选择器/URL 净化、暂存架、本地媒体压缩与 Vision OCR 圈选搜索）

**Files:**
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/SmartCodeDetector.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/URLCleaner.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/ClipboardManager.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/ClipboardPickerPanel.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/DropzoneShelfManager.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/MediaToolbox.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/VisionOCRService.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/CircleToSearchController.swift`
- Create: `Packages/StarIslandKit/Sources/ProductivityKit/ProductivityViews.swift`
- Test: `Packages/StarIslandKit/Tests/ProductivityKitTests/ProductivityKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`ConsumedEventStore`, `IslandStateMachine`, `SettingsStore`, `AIQueryServiceProtocol`)
- Produces:
  - `public enum SmartCodeDetector` (`static func detectOTP(title:body:appBundleID:) -> DetectedOTP?`, `static func detectParcel(in text: String) -> DetectedParcel?`)
  - `@MainActor public final class SmartInboxCoordinator: ObservableObject` (`ingestNotification(appBundleID:appName:title:body:) -> Bool`)
  - `public enum URLCleaner` (`static func clean(_ raw: String, customBlockedKeys: Set<String>) -> String?`)
  - `@MainActor public final class ClipboardManager: ObservableObject` (`ingestPasteboardSnapshot(...)`, `items`, `presentPicker()`, `clearAll()`)
  - `@MainActor public final class DropzoneShelfManager: ObservableObject` (`items`, `addFiles(_:)`, `remove(_:)`, `clear()`)
  - `public enum MediaToolbox` (`static func compressImage(at:quality:maxDimension:) throws -> MediaOptimizationReport`, `static func compressPDF(at:) throws -> MediaOptimizationReport`, `static func convertAudioOrVideo(at:preset:) async throws -> MediaOptimizationReport`)
  - `public enum VisionOCRService` (`static func recognizeText(in cgImage: CGImage) async throws -> String`)
  - `@MainActor public final class CircleToSearchController: ObservableObject` (`beginSelection(aiService:)`)
  - `public struct ShelfIslandTabView: View` & `public struct ProductivitySettingsPaneView: View`

- [ ] **Step 1: 在 `ProductivityKitTests.swift` 编写失败单测（含 Review Focus #1 与 #2 全部用例）**
  覆盖：Discord `"yetone (#general, Text Channels) 3068"` 严格返回 `nil`、年份/时间/金额返回 `nil`、中英文真实验证码精准提取且二次投递被 `ConsumedEventStore` 拦截返回 `false`、顺丰/UPS 单号识别、`ConcealedType` 密码剪贴板自动跳过、`URLCleaner` 剥离 `utm_*`/`fbclid`/`spm` 并保留正常参数、`ImageIO` 真实生成临时 PNG 压缩减体积校验、`VisionOCRService` 对渲染文字位图离线识别出准确文本。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter ProductivityKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `ProductivityKit` 全部服务、浮层窗口与视图**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter ProductivityKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 3**

---

### Task 4: `SystemEnhanceKit`（单总线 `EventTapBus`、窗口磁吸/切换器、Dock 实时窗口预览、键鼠增强、Emoji 联想与 Touch ID 应用锁）

**Files:**
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/EventTapBus.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/WindowRegistry.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/WindowSnapManager.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/DockPreviewController.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/KeyboardMouseEnhancers.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/EmojiSuggestEngine.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/AppLockService.swift`
- Create: `Packages/StarIslandKit/Sources/SystemEnhanceKit/SystemEnhanceSettingsView.swift`
- Test: `Packages/StarIslandKit/Tests/SystemEnhanceKitTests/SystemEnhanceKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`SettingsStore`, `IslandStateMachine`, `MutationJournal`)
- Produces:
  - `public final class EventTapBus` (`register(_:) -> UUID`, `unregister(_:)`, `static func dispatch(entries:eventType:context:) -> EventTapDisposition`)
  - `public enum SnapZone: String, CaseIterable, Sendable { case leftHalf, rightHalf, topMaximize, topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter, leftThird, centerThird, rightThird }`
  - `public enum WindowSnapGeometry` (`static func targetFrame(for zone: SnapZone, in visibleFrame: CGRect) -> CGRect`, `static func hoveredZone(cursor: CGPoint, in screenFrame: CGRect, edgeThreshold: CGFloat) -> SnapZone?`)
  - `@MainActor public final class WindowSnapManager: ObservableObject` & `@MainActor public final class DockPreviewController: ObservableObject`
  - `public struct ClickDebounceFilter` & `public struct HoldCommandQStateMachine` & `public enum EmojiSuggestEngine` (`static func match(token: String) -> [EmojiCandidate]`)
  - `@MainActor public final class AppLockService: ObservableObject` (`lockedBundleIDs`, `shouldBlockActivation(bundleID:now:) -> Bool`, `recordUnlock(bundleID:now:)`, `lockImmediately(bundleID:)`)
  - `public struct SystemEnhanceSettingsPaneView: View`

- [ ] **Step 1: 在 `SystemEnhanceKitTests.swift` 编写失败单测**
  覆盖：`EventTapBus` 优先级顺序与拦截短路、`WindowSnapGeometry` 10 种分屏区域矩形计算与边缘命中判定、鼠标微动防连击时间窗过滤、长按 `⌘Q` 计时达标放行与中途松开取消、`:火箭` / `:rocket` 中英文 Emoji 联想匹配、`AppLockService` 激活拦截与超时自动重锁策略。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter SystemEnhanceKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `SystemEnhanceKit` 全部管理器、浮层预览与 Touch ID 应用锁遮罩**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter SystemEnhanceKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 4**

---

### Task 5: `HardwareCleanKit`（特权 Helper 校验与协调器、SMC 电池风扇管家、应用深度卸载器与 DMG 安装器）

**Files:**
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/CodesignValidator.swift`
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/HelperCoordinator.swift`
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/BatteryFanManager.swift`
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/AppCleanerService.swift`
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/StorageAndDMGService.swift`
- Create: `Packages/StarIslandKit/Sources/HardwareCleanKit/HardwareCleanSettingsView.swift`
- Test: `Packages/StarIslandKit/Tests/HardwareCleanKitTests/HardwareCleanKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`PrivilegedHelperProtocol`, `MutationJournal`, `SettingsStore`)
- Produces:
  - `public enum CodesignValidator` (`static func isParentAppMatch(helperExecutableURL: URL, clientBundleURL: URL) -> Bool`, `static func validateClient(auditToken: audit_token_t) -> Bool`)
  - `@MainActor public final class HelperCoordinator: ObservableObject` (`status`, `isConnected`, `isReconciling`, `visibleIssue` — 握手完成前严禁报错；重装前先断 XPC 再 `unregister`)
  - `public enum BatteryChargePolicy` (`static func decideAction(level: Int, isCharging: Bool, limit: Int, sailingDrop: Int, temperatureC: Double, maxTempC: Double) -> ChargeControlAction`)
  - `public struct FanCurveProfile: Codable, Equatable, Sendable` (`targetRPM(forTemperatureC:minRPM:maxRPM:) -> Int`)
  - `@MainActor public final class BatteryFanManager: ObservableObject`
  - `public enum AppCleanerService` (`static func findResidueURLs(bundleID: String, appName: String, searchRoots: [URL]) -> [AppResidueItem]`)
  - `@MainActor public final class DMGAutoInstaller: ObservableObject`
  - `public struct HardwareCleanSettingsPaneView: View`

- [ ] **Step 1: 在 `HardwareCleanKitTests.swift` 编写失败单测**
  覆盖：父级 `.app` 包路径归属校验（匹配同包与拒绝异包）、`BatteryChargePolicy`（高温停充优先、达上限停充、巡航回落区间保持不充、低于下限恢复充电）、风扇温控线性插值曲线、模拟 `Library` 目录残留文件精准扫描（绝不误扫前缀相似的无辜应用）、`HelperCoordinator` 握手中 `visibleIssue == nil` 状态机单测。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter HardwareCleanKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `HardwareCleanKit` 全部服务与设置视图**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter HardwareCleanKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 5**

---

### Task 6: `LiveWidgetsKit`（免 Key 天气、ESPN 实时比分、股票/加密行情、日程会议、蓝牙电量、计时护眼、随身镜、终端活动与专注拦截）

**Files:**
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/WeatherService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/SportsLiveService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/FinanceLiveService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/CalendarBluetoothService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/TimersMirrorTerminalService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/FocusBlockerService.swift`
- Create: `Packages/StarIslandKit/Sources/LiveWidgetsKit/WidgetsIslandViews.swift`
- Test: `Packages/StarIslandKit/Tests/LiveWidgetsKitTests/LiveWidgetsKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`IslandStateMachine`, `SettingsStore`, `MutationJournal`, `PrivilegedHelperProtocol`)
- Produces:
  - `@MainActor public final class WeatherService: ObservableObject` (`OpenMeteoParser.parse(data:cityName:) throws -> WeatherSnapshot`)
  - `@MainActor public final class SportsLiveService: ObservableObject` (`ESPNScoreboardParser.parse(data:league:) throws -> [LiveMatch]`)
  - `@MainActor public final class FinanceLiveService: ObservableObject` (`YahooChartParser.parse(data:symbol:) throws -> MarketQuote`, `BinanceTickerParser.parse(data:) throws -> MarketQuote`)
  - `public enum MeetingLinkExtractor` (`static func extractJoinURL(from text: String) -> URL?`)
  - `@MainActor public final class TimersEyeBreakManager: ObservableObject` & `public enum TerminalShellHook` (`static var zshSnippet: String`)
  - `public enum HostsBlocklistRenderer` (`static func applyBlockDomains(_ domains: [String], to hostsContent: String) -> String`, `static func removeManagedBlock(from hostsContent: String) -> String`)
  - `public struct WidgetsIslandTabView: View` & `public struct LiveWidgetsSettingsPaneView: View`

- [ ] **Step 1: 在 `LiveWidgetsKitTests.swift` 编写失败单测**
  覆盖：Open-Meteo JSON 解析、ESPN NBA/足球实时比分 JSON 解析、Yahoo Finance 与 Binance 行情及火花线序列解析、Zoom/腾讯会议/飞书会议 URL 提取、`/etc/hosts` 受管标记块幂等注入与无损移除。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter LiveWidgetsKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `LiveWidgetsKit` 全部服务、小组件看板与设置视图**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter LiveWidgetsKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 6**

---

### Task 7: `AIConnectKit`（多模型 AI 灵动助手 + 手机免装 App 扫码局域网互联）

**Files:**
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/KeychainVault.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/AIProviders.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/AIAssistantCoordinator.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/LANContinuitySecurity.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/LANContinuityServer.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/MobileWebPortalHTML.swift`
- Create: `Packages/StarIslandKit/Sources/AIConnectKit/AIConnectViews.swift`
- Test: `Packages/StarIslandKit/Tests/AIConnectKitTests/AIConnectKitTests.swift`

**Interfaces:**
- Consumes: `IslandCore` (`AIQueryServiceProtocol`, `SettingsStore`, `IslandStateMachine`)
- Produces:
  - `public enum AIProviderKind: String, CaseIterable, Codable, Sendable { case gemini, openAICompatible, ollama }`
  - `public enum AIRequestBuilder` (`static func buildGeminiRequest(...)`, `static func buildOpenAIRequest(...)`, `static func buildOllamaRequest(...)`)
  - `@MainActor public final class AIAssistantCoordinator: ObservableObject, AIQueryServiceProtocol`
  - `public struct PairingTokenManager: Sendable` (`generateNewPIN() -> String`, `issueSessionToken(forPIN:) -> String?`, `isValidSession(_:) -> Bool`)
  - `public enum SafeFilenameSanitizer` (`static func sanitize(_ raw: String) -> String`)
  - `@MainActor public final class LANContinuityServer: ObservableObject` (`start()`, `stop()`, `pairingURL`, `qrCodeImage`)
  - `public struct AIIslandTabView: View`, `public struct ConnectIslandTabView: View`, `public struct AIConnectSettingsPaneView: View`

- [ ] **Step 1: 在 `AIConnectKitTests.swift` 编写失败单测（含 Review Focus #5 安全用例）**
  覆盖：Gemini / OpenAI 兼容 / Ollama 请求体与响应解析、6 位配对码校验通过签发令牌与错误配对码拒绝（401）、`SafeFilenameSanitizer` 拦截 `../../etc/passwd` 与空文件名路径穿越、QR 二维码位图生成非空校验。
- [ ] **Step 2: 运行测试验证 RED**
  Run: `swift test --filter AIConnectKitTests` -> Expected: FAIL
- [ ] **Step 3: 实现 `AIConnectKit` 全部服务、响应式中文手机互联 Web 端与灵动岛标签页**
- [ ] **Step 4: 运行测试验证 GREEN**
  Run: `swift test --filter AIConnectKitTests` -> Expected: PASS
- [ ] **Step 5: 提交 Task 7**

---

### Task 8: `StarIsland.app` 主应用组装、特权 Helper 守护进程、全中文设置中心、打包签名与 GitHub `v1.0.0` 发布

**Files:**
- Create: `Packages/StarIslandKit/Sources/StarIslandApp/StarIslandAppMain.swift`
- Create: `Packages/StarIslandKit/Sources/StarIslandApp/AppCoordinator.swift`
- Create: `Packages/StarIslandKit/Sources/StarIslandApp/UnifiedSettingsWindowView.swift`
- Create: `Packages/StarIslandKit/Sources/StarIslandApp/OnboardingWindowView.swift`
- Create: `Packages/StarIslandKit/Sources/StarIslandHelper/HelperMain.swift`
- Create: `App/Info.plist`
- Create: `App/StarIsland.entitlements`
- Create: `Helper/com.adgry.starisland.helper.plist`
- Create: `Helper/StarIslandHelper.entitlements`
- Create: `scripts/generate_icon.swift`
- Create: `scripts/build_app.sh`
- Create: `scripts/release.sh`
- Create: `.github/workflows/release.yml`
- Create: `README.md` & `.gitignore`

**Interfaces:**
- Consumes: Task 1 ～ Task 7 全部公开模块接口
- Produces:
  - 完整可运行 `/Applications/StarIsland.app`（含高精度星岛主题 `AppIcon.icns`、嵌套 `Contents/MacOS/com.adgry.starisland.helper`、`Contents/Library/LaunchDaemons/com.adgry.starisland.helper.plist`、双层 Ad-hoc 权限签名）
  - 远端仓库 `https://github.com/adgry/StarIsland` 及首个正式版 Release `v1.0.0`（附 `StarIsland-arm64.zip`）

- [ ] **Step 1: 在 `Package.swift` 注册 `StarIsland` 与 `com.adgry.starisland.helper` 两个可执行 Target，编写主程序编排器、五大标签页灵动岛宿主、模块化全中文设置中心（带全局实时搜索）与首次启动引导窗**
- [ ] **Step 2: 编写 `HelperMain.swift`（SMC 读写 + 安全路径校验 + 无感自更新安装器）及 `Info.plist` / `entitlements` / `generate_icon.swift` / `build_app.sh` / `release.sh` / `release.yml` / `README.md`**
- [ ] **Step 3: 运行全量 7 大测试套件验证 100% 通过**
  Run: `cd "/Volumes/D盘/mirasim_work/mac灵动岛/StarIsland/Packages/StarIslandKit" && swift test`
  Expected: 全部 7 个 Test Suite 100% PASS，0 failures
- [ ] **Step 4: 执行 `scripts/build_app.sh 1.0.0` 构建并验证 `StarIsland.app` 包结构与代码签名**
  Run: `./scripts/build_app.sh 1.0.0 && codesign --verify --deep --strict dist/release-1.0.0/StarIsland.app`
  Expected: Exit code `0`
- [ ] **Step 5: 派发独立代码审查子智能体执行全分支质量与规格符合度审查，修复所有 Critical/Important 问题并重跑单测**
- [ ] **Step 6: 安装 `/Applications/StarIsland.app` 实机启动并检查运行进程与系统日志，创建 `adgry/StarIsland` GitHub 仓库并执行 `./scripts/release.sh 1.0.0` 发布正式安装包**
