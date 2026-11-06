//
//  SettingsAssistant.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-26

import Combine
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class SettingsAssistant: ObservableObject {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant }

        let id = UUID()
        let role: Role
        var text: String
        var changes: [SettingsIndex.Change] = []
        var suggestions: [SettingsIndex.Entry] = []
        var isError = false
    }

    @Published private(set) var messages: [Message] = []
    @Published private(set) var isResponding = false
    @Published private(set) var undoneChangeIDs: Set<UUID> = []

    private weak var editingSession: SettingsEditingSession?
    private var turnChanges: [SettingsIndex.Change] = []
    private var turnSuggestions: [SettingsIndex.Entry] = []
    private var responseTask: Task<Void, Never>?
    #if canImport(FoundationModels)
    private var storedSession: AnyObject?
    #endif

    nonisolated static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }

    var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.appleIntelligenceNotEnabled):
                return "请在“系统设置”中开启 Apple 智能，以使用设置提问与助手功能。"
            case .unavailable(.modelNotReady):
                return "Apple 智能正在准备中，请稍后再试。"
            case .unavailable(.deviceNotEligible):
                return "此 Mac 不支持 Apple 智能。"
            case .unavailable:
                return "Apple 智能当前不可用。"
            }
        }
        #endif
        return "设置助手需要 macOS 26 或更高版本。"
    }

    func attach(_ session: SettingsEditingSession) {
        editingSession = session
    }

    func clearConversation() {
        responseTask?.cancel()
        messages = []
        undoneChangeIDs = []
        isResponding = false
        #if canImport(FoundationModels)
        storedSession = nil
        #endif
    }

    func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }
        messages.append(Message(role: .user, text: prompt))
        guard unavailableReason == nil else {
            messages.append(Message(role: .assistant, text: unavailableReason ?? "", isError: true))
            return
        }
        isResponding = true
        turnChanges = []
        turnSuggestions = []
        responseTask = Task { [weak self] in
            await self?.respond(to: prompt)
        }
    }

    private func respond(to prompt: String) async {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let grounded = groundedPrompt(prompt)
            var outcome = "未做任何修改。"
            if !Self.isQuestion(prompt), let decision = try? await requestedChange(in: grounded) {
                var value = decision.value
                if let entry = SettingsIndex.byKey[decision.key],
                   case .bool? = SettingsIndex.value(of: entry.key, in: currentSettings),
                   let on = Self.impliedToggle(in: prompt, title: entry.displayTitle) {
                    value = on ? "on" : "off"
                }
                outcome = change(key: decision.key, to: value)
            }
            guard !Task.isCancelled else { return }
            let turn = grounded + "\n\nSapphire 执行结果：" + outcome
            var reply: String
            var failed = false
            do {
                reply = try await languageSession().respond(to: turn).content
            } catch let error as LanguageModelSession.GenerationError {
                if case .exceededContextWindowSize = error {
                    storedSession = nil
                    reply = (try? await languageSession().respond(to: turn).content)
                        ?? "当前对话过长，请重新提问以开启新会话。"
                } else {
                    reply = error.localizedDescription
                    failed = true
                }
            } catch {
                reply = error.localizedDescription
                failed = true
            }
            guard !Task.isCancelled else { return }
            let changedKeys = Set(turnChanges.map(\.entry.key))
            let suggestions = turnSuggestions.filter { !changedKeys.contains($0.key) }
            messages.append(Message(
                role: .assistant,
                text: reply.trimmingCharacters(in: .whitespacesAndNewlines),
                changes: turnChanges,
                suggestions: Array(suggestions.prefix(4)),
                isError: failed
            ))
            isResponding = false
            return
        }
        #endif
        isResponding = false
    }

    nonisolated static func isQuestion(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let requests = [
            "can you ", "could you ", "would you ", "will you ", "please ",
            "请", "帮我", "麻烦", "能帮我", "可以帮我"
        ]
        if requests.contains(where: lowered.hasPrefix) { return false }
        let questions = ["can i ", "could i ", "how ", "is ", "are ", "does ", "do ", "what ", "where ", "which ", "why ", "should ", "am i "]
        if lowered.hasSuffix("?") || lowered.hasSuffix("？") || questions.contains(where: lowered.hasPrefix) {
            return true
        }
        let cjkQuestionMarkers = ["怎么", "如何", "在哪", "为什么", "是什么", "多少", "能否", "能不能", "可以", "有没有", "是否", "吗"]
        return cjkQuestionMarkers.contains(where: lowered.contains)
    }

    nonisolated static func impliedToggle(in message: String, title: String) -> Bool? {
        let text = " " + message.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ") + " "
        let rawMessage = message.lowercased()
        let titled = title.lowercased()
        var on = [" turn on ", " switch on ", " enable ", " activate ", " start "].contains(where: text.contains)
            || ["开启", "打开", "启用", "激活"].contains(where: rawMessage.contains)
        var off = [" turn off ", " switch off ", " disable ", " deactivate ", " stop "].contains(where: text.contains)
            || ["关闭", "关掉", "禁用", "停用"].contains(where: rawMessage.contains)
        let hide = text.contains(" hide ") || rawMessage.contains("隐藏")
        let show = text.contains(" show ") || text.contains(" unhide ") || rawMessage.contains("显示") || rawMessage.contains("取消隐藏")
        if titled.hasPrefix("hide") || title.hasPrefix("隐藏") {
            on = on || hide
            off = off || show
        } else if titled.hasPrefix("show") || title.hasPrefix("显示") {
            on = on || show
            off = off || hide
        }
        return on == off ? nil : on
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func languageSession() -> LanguageModelSession {
        if let session = storedSession as? LanguageModelSession { return session }
        let session = LanguageModelSession(
            tools: [FindSettingsTool(assistant: self)],
            instructions: Self.instructions
        )
        storedSession = session
        return session
    }

    @available(macOS 26.0, *)
    private func requestedChange(in grounded: String) async throws -> (key: String, value: String)? {
        let session = LanguageModelSession(instructions: Self.decisionInstructions)
        let decision = try await session.respond(to: grounded, generating: ChangeDecision.self).content
        guard decision.kind == .change, !decision.key.isEmpty else { return nil }
        return (decision.key, decision.value)
    }

    private static let decisionInstructions = """
    你负责判断用户发送给 Sapphire 设置助手的消息是否是修改某项设置的明确指令，以及对应哪一项设置。\
    疑问句绝不触发任何修改。只能使用已列出设置项中的精确 key。\
    对于标题以“隐藏”或“Hide”开头的设置项，on 表示隐藏。
    """

    private static let instructions = """
    你是 Sapphire 内置的设置助手。Sapphire 是一款为 Mac 提供灵动岛、实时活动、小组件、音乐播放器与系统增强工具的应用。
    请使用简体中文回答有关 Sapphire 功能与设置调整方式的问题。每次提问都会附带匹配到的设置项，请优先基于这些设置项作答。\
    如果没有合适匹配项，请先使用不同关键词调用 findSettings 工具查找，不要凭空捏造不存在的设置项或分类面板。
    Sapphire 的设置分类面板：
    \(paneCatalog)
    每条消息末尾都会标明 Sapphire 实际执行的结果。请如实反馈已完成的修改或失败原因，绝不要声称修改了实际未改动的设置。\
    当用户询问某功能是否支持或寻求建议时，介绍匹配的设置项及其所在面板；只有在用户明确指令修改时才更改设置。
    回答保持简明扼要（两到四句话），并点明设置项所在的分类面板名称。
    """

    private static let paneCatalog = SettingsSection.allCases
        .filter { $0 != .overview && $0 != .about }
        .map { "- \($0.label)：\($0.shortDescription)" }
        .joined(separator: "\n")
    #endif

    private func groundedPrompt(_ prompt: String) -> String {
        var query = prompt
        if SettingsIndex.search(prompt, limit: 1).isEmpty,
           let previous = messages.dropLast().last(where: { $0.role == .user }) {
            query = previous.text + " " + prompt
        }
        return """
        \(prompt)

        与此消息匹配的设置项：
        \(find(query, limit: 8))
        """
    }

    // MARK: - Tool actions

    func find(_ query: String, limit: Int = 6) -> String {
        let matches = SettingsIndex.search(query, limit: limit)
        guard !matches.isEmpty else {
            return "没有匹配“\(query)”的设置项，请尝试更换关键词。"
        }
        let settings = currentSettings
        for entry in matches where !turnSuggestions.contains(entry) {
            turnSuggestions.append(entry)
        }
        return matches.map { entry in
            var line = "key=\(entry.key) | \"\(entry.displayTitle)\""
            if let section = entry.section { line += " | 面板：\(section.label)" }
            if let value = SettingsIndex.value(of: entry.key, in: settings) { line += " | 当前值：\(value.description)" }
            if let allowed = SettingsIndex.rangeDescription(entry) {
                line += " | 可选范围：\(allowed)"
            } else if case .bool? = SettingsIndex.value(of: entry.key, in: settings) {
                line += " | 可选范围：on / off"
            }
            if entry.section?.isPremiumLocked == true { line += " | 需要 Sapphire 订阅" }
            if let detail = entry.detail { line += " | " + String(detail.prefix(110)) }
            return line
        }.joined(separator: "\n")
    }

    func change(key: String, to rawValue: String) -> String {
        let current = currentSettings
        switch SettingsIndex.applying(key: key, rawValue: rawValue, to: current) {
        case .failure(let error):
            return "未修改：\(error.description)"
        case .success(let (updated, change)):
            if change.oldValue == change.newValue {
                return "“\(change.entry.displayTitle)”当前已是 \(change.newValue.localizedDescription)，无需更改。"
            }
            commit(updated)
            turnChanges.append(change)
            return "已将“\(change.entry.displayTitle)”从 \(change.oldValue.localizedDescription) 更改为 \(change.newValue.localizedDescription)。"
        }
    }

    func undo(_ change: SettingsIndex.Change) {
        let current = currentSettings
        guard case .success(let (updated, _)) = SettingsIndex.applying(
            key: change.entry.key,
            rawValue: change.oldValue.description,
            to: current
        ) else { return }
        commit(updated)
        undoneChangeIDs.insert(change.id)
    }

    private var currentSettings: Settings {
        editingSession?.settings.value ?? SettingsModel.shared.settings
    }

    private func commit(_ settings: Settings) {
        if let editingSession {
            editingSession.settings.value = settings
        } else {
            SettingsModel.shared.settings = settings
        }
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private struct FindSettingsTool: Tool {
    let name = "findSettings"
    let description = "按中英文关键词搜索 Sapphire 设置项，返回匹配设置的 key、标题、分类面板、当前值与允许范围。"

    @Generable
    struct Arguments {
        @Guide(description: "描述目标设置的几个关键词，例如“全屏隐藏灵动岛”或“音乐波形条数”。")
        var query: String
    }

    let assistant: SettingsAssistant

    func call(arguments: Arguments) async throws -> String {
        await assistant.find(arguments.query)
    }
}

@available(macOS 26.0, *)
@Generable
private enum RequestKind {
    case change, question
}

@available(macOS 26.0, *)
@Generable
private struct ChangeDecision {
    @Guide(description: "仅当消息是明确修改指令（如“关闭 X”、“开启 X”、“把 X 设为 5”、“隐藏 X”）时返回 change；疑问句（如“怎么…？”、“可以…吗？”）或征求建议时返回 question。")
    var kind: RequestKind
    @Guide(description: "若为 change，填写所列设置项的精确 key；否则留空。")
    var key: String
    @Guide(description: "若为 change，填写允许范围内的新值：开启/打开/启用/显示填 on；关闭/禁用/停止/隐藏填 off；其余设置填数字或选项名；否则留空。")
    var value: String
}
#endif
