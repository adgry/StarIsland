import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IslandCore
import SwiftUI

/// Emoji 候选词条
public struct EmojiCandidate: Identifiable, Equatable, Sendable {
    public let emoji: String
    public let primaryName: String
    public let keywords: [String]

    public var id: String { emoji }

    public init(emoji: String, primaryName: String, keywords: [String]) {
        self.emoji = emoji
        self.primaryName = primaryName
        self.keywords = keywords
    }
}

/// 中英文双语 `:关键词` Emoji 联想搜索引擎
public enum EmojiSuggestEngine {
    public static func match(token: String) -> [EmojiCandidate] {
        match(token: token, limit: 8)
    }

    public static func match(token: String, limit: Int) -> [EmojiCandidate] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }) else {
            return []
        }

        var normalized = trimmed
        if normalized.hasPrefix(":") || normalized.hasPrefix("：") {
            normalized.removeFirst()
        }
        if normalized.hasSuffix(":") || normalized.hasSuffix("：") {
            normalized.removeLast()
        }

        let query = normalized.lowercased()
        guard !query.isEmpty, limit > 0 else {
            return []
        }

        var scored: [(index: Int, score: Int, candidate: EmojiCandidate)] = []
        for (idx, item) in catalog.enumerated() {
            let nameLower = item.primaryName.lowercased()
            let lowerKeywords = item.keywords.map { $0.lowercased() }

            let score: Int
            if nameLower == query || lowerKeywords.contains(query) {
                score = 300
            } else if nameLower.hasPrefix(query) || lowerKeywords.contains(where: { $0.hasPrefix(query) }) {
                score = 200
            } else if nameLower.contains(query) || lowerKeywords.contains(where: { $0.contains(query) }) {
                score = 100
            } else {
                continue
            }
            scored.append((idx, score, item))
        }

        scored.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.index < rhs.index
        }

        return Array(scored.prefix(limit).map(\.candidate))
    }

    /// 从连续输入缓冲末尾提取当前正在键入的 `:关键词` 片段
    public static func extractTrailingColonToken(from buffer: String) -> String? {
        guard let colonIdx = buffer.lastIndex(where: { $0 == ":" || $0 == "：" }) else {
            return nil
        }
        let suffix = String(buffer[colonIdx...])
        guard suffix.count >= 2, suffix.count <= 18,
              !suffix.contains(where: { $0.isWhitespace }) else {
            return nil
        }
        return suffix
    }

    /// 内置高频中英文 Emoji 词典
    public static let catalog: [EmojiCandidate] = [
        // 科技、效率与发布
        EmojiCandidate(emoji: "🚀", primaryName: "火箭", keywords: ["火箭", "发射", "起飞", "上线", "rocket", "launch", "ship"]),
        EmojiCandidate(emoji: "✨", primaryName: "闪耀", keywords: ["闪耀", "星星", "新功能", "亮晶晶", "sparkles", "magic", "new"]),
        EmojiCandidate(emoji: "🔥", primaryName: "火焰", keywords: ["火焰", "火", "热门", "燃", "fire", "hot", "lit"]),
        EmojiCandidate(emoji: "⚡", primaryName: "闪电", keywords: ["闪电", "极速", "雷电", "充电", "zap", "bolt", "fast"]),
        EmojiCandidate(emoji: "💡", primaryName: "灵感", keywords: ["灵感", "灯泡", "想法", "提示", "bulb", "idea", "tip"]),
        EmojiCandidate(emoji: "🎯", primaryName: "命中", keywords: ["命中", "目标", "靶心", "精准", "dart", "target", "goal"]),
        EmojiCandidate(emoji: "🐛", primaryName: "臭虫", keywords: ["臭虫", "漏洞", "缺陷", "虫子", "bug", "fix"]),
        EmojiCandidate(emoji: "🛠️", primaryName: "工具", keywords: ["工具", "修复", "维护", "施工", "tools", "wrench", "build"]),
        EmojiCandidate(emoji: "💻", primaryName: "电脑", keywords: ["电脑", "笔记本", "编程", "代码", "laptop", "mac", "code"]),
        EmojiCandidate(emoji: "📱", primaryName: "手机", keywords: ["手机", "移动", "扫码", "iphone", "phone", "mobile"]),
        EmojiCandidate(emoji: "🔒", primaryName: "锁定", keywords: ["锁定", "加锁", "安全", "隐私", "lock", "secure", "privacy"]),
        EmojiCandidate(emoji: "🔓", primaryName: "解锁", keywords: ["解锁", "打开", "unlock", "open"]),
        EmojiCandidate(emoji: "🔍", primaryName: "搜索", keywords: ["搜索", "放大镜", "查找", "search", "find", "zoom"]),
        EmojiCandidate(emoji: "📌", primaryName: "图钉", keywords: ["图钉", "置顶", "标记", "pin", "top"]),
        EmojiCandidate(emoji: "📎", primaryName: "回形针", keywords: ["回形针", "附件", "链接", "clip", "attach"]),

        // 情绪与面部表情
        EmojiCandidate(emoji: "😂", primaryName: "笑哭", keywords: ["大笑", "笑哭", "喜极而泣", "哈哈", "joy", "laugh", "lol"]),
        EmojiCandidate(emoji: "😄", primaryName: "大笑", keywords: ["大笑", "开心", "露齿笑", "高兴", "smile", "grin", "happy"]),
        EmojiCandidate(emoji: "🤣", primaryName: "捧腹大笑", keywords: ["大笑", "笑翻", "满地打滚", "rofl", "lmao"]),
        EmojiCandidate(emoji: "😊", primaryName: "微笑", keywords: ["微笑", "害羞", "温暖", "blush", "warm"]),
        EmojiCandidate(emoji: "😍", primaryName: "喜爱", keywords: ["喜爱", "花痴", "心动", "超爱", "heart_eyes", "love"]),
        EmojiCandidate(emoji: "🥳", primaryName: "庆祝表情", keywords: ["庆祝", "派对", "生日", "party", "celebrate"]),
        EmojiCandidate(emoji: "😎", primaryName: "酷", keywords: ["酷", "墨镜", "帅", "cool", "sunglasses"]),
        EmojiCandidate(emoji: "🤔", primaryName: "思考", keywords: ["思考", "想一想", "疑惑", "thinking", "hmm"]),
        EmojiCandidate(emoji: "😭", primaryName: "大哭", keywords: ["大哭", "流泪", "伤心", "感动", "sob", "cry"]),
        EmojiCandidate(emoji: "😅", primaryName: "流汗笑", keywords: ["尴尬", "流汗", "苦笑", "sweat_smile", "awkward"]),
        EmojiCandidate(emoji: "🥹", primaryName: "感动", keywords: ["感动", "忍住眼泪", "破防", "touched"]),
        EmojiCandidate(emoji: "😴", primaryName: "困倦", keywords: ["睡觉", "困", "晚安", "sleep", "zzz"]),
        EmojiCandidate(emoji: "🤯", primaryName: "震撼", keywords: ["震撼", "脑洞大开", "头炸了", "mindblown", "explode"]),
        EmojiCandidate(emoji: "🫡", primaryName: "敬礼", keywords: ["敬礼", "收到", "遵命", "salute", "roger"]),

        // 手势与反馈符号
        EmojiCandidate(emoji: "👍", primaryName: "点赞", keywords: ["点赞", "赞", "大拇指", "同意", "好", "thumbsup", "good", "ok", "yes"]),
        EmojiCandidate(emoji: "👎", primaryName: "踩", keywords: ["不赞", "反对", "差评", "thumbsdown", "bad"]),
        EmojiCandidate(emoji: "👏", primaryName: "鼓掌", keywords: ["鼓掌", "拍手", "喝彩", "clap", "bravo"]),
        EmojiCandidate(emoji: "🙏", primaryName: "感谢", keywords: ["感谢", "拜托", "谢谢", "祈祷", "pray", "thanks", "please"]),
        EmojiCandidate(emoji: "🤝", primaryName: "握手", keywords: ["握手", "合作", "成交", "handshake", "deal"]),
        EmojiCandidate(emoji: "💪", primaryName: "加油", keywords: ["加油", "力量", "肌肉", "muscle", "strong", "fighting"]),
        EmojiCandidate(emoji: "👋", primaryName: "挥手", keywords: ["挥手", "你好", "再见", "wave", "hello", "bye"]),
        EmojiCandidate(emoji: "👌", primaryName: "没问题", keywords: ["没问题", "好的", "完美", "okay", "perfect"]),
        EmojiCandidate(emoji: "🎉", primaryName: "礼花", keywords: ["礼花", "庆祝", "恭喜", "撒花", "tada", "congrats"]),
        EmojiCandidate(emoji: "❤️", primaryName: "红心", keywords: ["爱心", "红心", "心", "喜欢", "heart", "love"]),
        EmojiCandidate(emoji: "💯", primaryName: "满分", keywords: ["满分", "一百", "完美", "100", "hundred"]),

        // 状态标记与办公
        EmojiCandidate(emoji: "✅", primaryName: "完成", keywords: ["完成", "通过", "对勾", "正确", "check", "done", "pass"]),
        EmojiCandidate(emoji: "❌", primaryName: "错误", keywords: ["错误", "关闭", "叉号", "拒绝", "cross", "fail", "error", "no"]),
        EmojiCandidate(emoji: "⚠️", primaryName: "警告", keywords: ["警告", "注意", "风险", "warning", "warn", "alert"]),
        EmojiCandidate(emoji: "ℹ️", primaryName: "信息", keywords: ["信息", "说明", "info", "note"]),
        EmojiCandidate(emoji: "⏰", primaryName: "闹钟", keywords: ["闹钟", "时间", "提醒", "倒计时", "alarm", "timer", "clock"]),
        EmojiCandidate(emoji: "📅", primaryName: "日历", keywords: ["日历", "日程", "会议", "calendar", "date", "schedule"]),
        EmojiCandidate(emoji: "📦", primaryName: "包裹", keywords: ["包裹", "快递", "打包", "package", "box", "parcel"]),
        EmojiCandidate(emoji: "📁", primaryName: "文件夹", keywords: ["文件夹", "目录", "归档", "folder", "dir"]),
        EmojiCandidate(emoji: "📈", primaryName: "上涨", keywords: ["上涨", "增长", "股票", "趋势", "chart_up", "bull", "up"]),
        EmojiCandidate(emoji: "📉", primaryName: "下跌", keywords: ["下跌", "下降", "chart_down", "down"]),

        // 生活、天气与自然
        EmojiCandidate(emoji: "☀️", primaryName: "晴天", keywords: ["太阳", "晴天", "阳光", "sun", "sunny"]),
        EmojiCandidate(emoji: "🌧️", primaryName: "下雨", keywords: ["下雨", "雨天", "rain", "rainy"]),
        EmojiCandidate(emoji: "🌙", primaryName: "月亮", keywords: ["月亮", "夜晚", "深色", "moon", "night"]),
        EmojiCandidate(emoji: "⭐", primaryName: "五角星", keywords: ["星星", "收藏", "星岛", "star", "fav"]),
        EmojiCandidate(emoji: "☕", primaryName: "咖啡", keywords: ["咖啡", "下午茶", "休息", "coffee", "cafe"]),
        EmojiCandidate(emoji: "🍵", primaryName: "热茶", keywords: ["茶", "绿茶", "喝茶", "tea"]),
        EmojiCandidate(emoji: "🍎", primaryName: "苹果", keywords: ["苹果", "水果", "apple"]),
        EmojiCandidate(emoji: "🐱", primaryName: "猫咪", keywords: ["猫", "猫咪", "喵", "cat", "kitty"]),
        EmojiCandidate(emoji: "🐶", primaryName: "小狗", keywords: ["狗", "小狗", "旺", "dog", "puppy"]),
        EmojiCandidate(emoji: "🎵", primaryName: "音符", keywords: ["音乐", "音符", "歌曲", "music", "song"])
    ]
}

/// 全局 `:关键词` Emoji 联想输入追踪与候选浮窗控制器
@MainActor
public final class EmojiInputController: ObservableObject {
    public static let shared = EmojiInputController()

    @Published public private(set) var candidates: [EmojiCandidate] = []
    @Published public private(set) var activeToken: String = ""
    @Published public var selectedIndex: Int = 0
    @Published public private(set) var isPanelVisible: Bool = false

    private final class LockedBufferState: @unchecked Sendable {
        let lock = NSLock()
        var rollingBuffer: String = ""
        var isInjectingSyntheticKeys: Bool = false
    }

    private let settingsStore: SettingsStore
    private let eventTapBus: EventTapBus
    private let bufferState = LockedBufferState()
    private var tapRegistrationID: UUID?
    private var panel: NSPanel?

    public init(
        settingsStore: SettingsStore? = nil,
        eventTapBus: EventTapBus? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.eventTapBus = eventTapBus ?? .shared
    }

    public func start() {
        guard tapRegistrationID == nil else { return }
        let mask = EventTapEntry.mask(for: [.keyDown, .leftMouseDown, .rightMouseDown])
        let entry = EventTapEntry(name: "EmojiShortcutTracker", priority: 72, eventMask: mask) { [weak self] context in
            guard let self else { return .passThrough }
            return self.handleEventNonisolated(context)
        }
        tapRegistrationID = eventTapBus.register(entry)
    }

    public func stop() {
        if let id = tapRegistrationID {
            eventTapBus.unregister(id)
            tapRegistrationID = nil
        }
        resetSession()
    }

    public func commitCandidate(_ candidate: EmojiCandidate) {
        let replaceLength = activeToken.count
        resetSession()
        guard replaceLength > 0 else { return }

        bufferState.lock.lock()
        bufferState.isInjectingSyntheticKeys = true
        bufferState.lock.unlock()

        Task.detached(priority: .high) { [weak self] in
            // 先退格擦除 `:关键词`
            for _ in 0..<replaceLength {
                if let down = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true),
                   let up = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false) {
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            }

            // 直接注入 Unicode Emoji 字符（无需污染用户系统剪贴板）
            let utf16Units = Array(candidate.emoji.utf16)
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: utf16Units)
                up.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: utf16Units)
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }

            try? await Task.sleep(nanoseconds: 40_000_000)
            self?.clearSyntheticFlagNonisolated()
        }
    }

    public func resetSession() {
        bufferState.lock.lock()
        bufferState.rollingBuffer = ""
        bufferState.lock.unlock()
        activeToken = ""
        candidates = []
        selectedIndex = 0
        panel?.orderOut(nil)
        isPanelVisible = false
    }

    private nonisolated func clearSyntheticFlagNonisolated() {
        bufferState.lock.lock()
        bufferState.isInjectingSyntheticKeys = false
        bufferState.lock.unlock()
    }

    private nonisolated func handleEventNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        bufferState.lock.lock()
        let synthetic = bufferState.isInjectingSyntheticKeys
        bufferState.lock.unlock()
        if synthetic { return .passThrough }

        if context.eventType == .leftMouseDown || context.eventType == .rightMouseDown {
            Task { @MainActor [weak self] in
                guard let self, self.isPanelVisible else { return }
                let clickAppKit = AXWindowHelper.appKitPoint(fromQuartz: context.location)
                if let panel = self.panel, panel.frame.contains(clickAppKit) {
                    return
                }
                self.resetSession()
            }
            return .passThrough
        }

        var enabled = false
        var visible = false
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                enabled = self.settingsStore.settings.enableEmojiShortcut
                visible = self.isPanelVisible
            }
        }
        guard enabled else { return .passThrough }

        // 存在命令键或控制键时清空缓冲并原样放行
        if context.flags.contains(.maskCommand) || context.flags.contains(.maskControl) {
            bufferState.lock.lock()
            bufferState.rollingBuffer = ""
            bufferState.lock.unlock()
            if visible {
                Task { @MainActor [weak self] in self?.resetSession() }
            }
            return .passThrough
        }

        // 若候选窗正在显示，支持 Esc / Tab / 回车 / 上下键快速上屏
        if visible {
            switch context.keyCode {
            case 53: // Esc
                Task { @MainActor [weak self] in self?.resetSession() }
                return .suppress
            case 36, 48: // Return 或 Tab 选中当前候选上屏
                Task { @MainActor [weak self] in
                    guard let self, self.candidates.indices.contains(self.selectedIndex) else { return }
                    self.commitCandidate(self.candidates[self.selectedIndex])
                }
                return .suppress
            case 123, 126: // Left / Up
                Task { @MainActor [weak self] in
                    guard let self, !self.candidates.isEmpty else { return }
                    self.selectedIndex = (self.selectedIndex - 1 + self.candidates.count) % self.candidates.count
                }
                return .suppress
            case 124, 125: // Right / Down
                Task { @MainActor [weak self] in
                    guard let self, !self.candidates.isEmpty else { return }
                    self.selectedIndex = (self.selectedIndex + 1) % self.candidates.count
                }
                return .suppress
            default:
                break
            }
        }

        // 退格键同步回退滚动缓冲
        if context.keyCode == 51 {
            bufferState.lock.lock()
            if !bufferState.rollingBuffer.isEmpty { bufferState.rollingBuffer.removeLast() }
            let snapshot = bufferState.rollingBuffer
            bufferState.lock.unlock()
            Task { @MainActor [weak self] in
                self?.refreshCandidates(fromBuffer: snapshot)
            }
            return .passThrough
        }

        let chars = context.unicodeCharacters
        guard !chars.isEmpty else { return .passThrough }

        if chars.contains(where: { $0.isWhitespace || $0.isNewline }) {
            bufferState.lock.lock()
            bufferState.rollingBuffer = ""
            bufferState.lock.unlock()
            if visible {
                Task { @MainActor [weak self] in self?.resetSession() }
            }
            return .passThrough
        }

        bufferState.lock.lock()
        bufferState.rollingBuffer.append(chars)
        if bufferState.rollingBuffer.count > 24 {
            bufferState.rollingBuffer = String(bufferState.rollingBuffer.suffix(24))
        }
        let snapshot = bufferState.rollingBuffer
        bufferState.lock.unlock()

        Task { @MainActor [weak self] in
            self?.refreshCandidates(fromBuffer: snapshot)
        }
        return .passThrough
    }

    private func refreshCandidates(fromBuffer buffer: String) {
        guard let token = EmojiSuggestEngine.extractTrailingColonToken(from: buffer) else {
            if isPanelVisible {
                activeToken = ""
                candidates = []
                panel?.orderOut(nil)
                isPanelVisible = false
            }
            return
        }

        let matched = EmojiSuggestEngine.match(token: token, limit: 6)
        guard !matched.isEmpty else {
            panel?.orderOut(nil)
            isPanelVisible = false
            return
        }

        activeToken = token
        candidates = matched
        selectedIndex = 0
        presentPanelNearCaretOrCursor()
    }

    private func presentPanelNearCaretOrCursor() {
        if panel == nil {
            let created = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 52),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            created.isFloatingPanel = true
            created.level = .popUpMenu
            created.backgroundColor = .clear
            created.isOpaque = false
            created.hasShadow = true
            created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            created.contentView = NSHostingView(rootView: EmojiSuggestionBarView(controller: self))
            panel = created
        }

        guard let panel else { return }
        let anchor = Self.focusedCaretAppKitPoint() ?? NSEvent.mouseLocation
        let size = CGSize(width: min(CGFloat(candidates.count) * 74 + 28, 460), height: 50)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let x = min(max(anchor.x, bounds.minX + 10), bounds.maxX - size.width - 10)
        let y = max(anchor.y - size.height - 8, bounds.minY + 10)
        panel.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), display: true)
        panel.orderFrontRegardless()
        isPanelVisible = true
    }

    private static func focusedCaretAppKitPoint() -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let element = focusedRef,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }

        let axEl = element as! AXUIElement
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axEl, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeVal = rangeRef {
            var boundsRef: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                axEl,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeVal,
                &boundsRef
            ) == .success,
               let bVal = boundsRef,
               CFGetTypeID(bVal) == AXValueGetTypeID() {
                var quartzRect = CGRect.zero
                if AXValueGetValue(bVal as! AXValue, .cgRect, &quartzRect), quartzRect.width >= 0 {
                    let appKitRect = AXWindowHelper.appKitRect(fromQuartz: quartzRect)
                    return CGPoint(x: appKitRect.minX, y: appKitRect.minY)
                }
            }
        }
        return nil
    }
}

private struct EmojiSuggestionBarView: View {
    @ObservedObject var controller: EmojiInputController

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(controller.candidates.enumerated()), id: \.element.id) { idx, item in
                let selected = (idx == controller.selectedIndex)
                Button {
                    controller.commitCandidate(item)
                } label: {
                    HStack(spacing: 4) {
                        Text(item.emoji)
                            .font(.system(size: 18))
                        Text(item.primaryName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}
