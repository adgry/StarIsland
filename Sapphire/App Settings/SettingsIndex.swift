//
//  SettingsIndex.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-26

import Foundation

enum SettingsIndex {
    struct Entry: Identifiable, Hashable {
        let key: String
        let title: String?
        let detail: String?
        let section: SettingsSection?
        let range: ClosedRange<Double>?
        let options: [String]?

        var id: String { key }

        var displayTitle: String { title ?? SettingsIndex.humanized(key) }
    }

    enum Value: Equatable {
        case bool(Bool)
        case number(Double)
        case text(String)

        var description: String {
            switch self {
            case .bool(let on): return on ? "on" : "off"
            case .number(let value):
                return value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
            case .text(let text): return text
            }
        }

        var localizedDescription: String {
            switch self {
            case .bool(let on): return on ? "开启" : "关闭"
            case .number, .text: return description
            }
        }
    }

    struct Change: Identifiable, Equatable {
        let id = UUID()
        let entry: Entry
        let oldValue: Value
        let newValue: Value
    }

    enum ChangeError: Error, CustomStringConvertible {
        case unknownSetting(String)
        case invalidValue(key: String, expected: String)

        var description: String {
            switch self {
            case .unknownSetting(let key):
                return "未找到名为“\(key)”的设置项，请先搜索确认。"
            case .invalidValue(let key, let expected):
                return "“\(key)”无法使用该值，期望值为：\(expected)。"
            }
        }
    }

    static let entries: [Entry] = generatedEntries
    static let byKey: [String: Entry] = Dictionary(entries.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

    // MARK: - Search

    static func search(_ query: String, limit: Int = 6) -> [Entry] {
        let latinTyped = extractLatinWords(query)
            .filter { $0.count > 1 && !stopWords.contains($0) }
        let cjkTyped = extractCJKTerms(query)

        var tokens = Set(latinTyped.map(stem))
        for word in latinTyped {
            synonyms[word]?.forEach { syn in
                if containsCJK(syn) {
                    tokens.insert(syn)
                } else {
                    tokens.insert(stem(syn))
                }
            }
        }
        for term in cjkTyped {
            tokens.insert(term)
            cjkSynonyms[term]?.forEach { syn in
                if containsCJK(syn) {
                    tokens.insert(syn)
                } else {
                    tokens.insert(stem(syn.lowercased()))
                }
            }
        }
        guard !tokens.isEmpty else { return [] }

        let weights = Dictionary(uniqueKeysWithValues: tokens.map { word -> (String, Double) in
            let hits = searchText.filter { $0.matches(word) }.count
            return (word, log(Double(entries.count + 1) / Double(hits + 1)))
        })

        let scored: [(Entry, Double)] = zip(entries, searchText).compactMap { entry, text in
            var score = 0.0
            var matched = 0
            for word in tokens {
                var hit = 0.0
                if containsCJK(word) {
                    let lengthBoost = word.count >= 2 ? 1.0 : 0.55
                    if text.rawTitle == word {
                        hit += 6 * lengthBoost
                    } else if text.rawTitle.contains(word) {
                        hit += 4 * lengthBoost
                    }
                    if text.rawPane.contains(word) { hit += 1.5 * lengthBoost }
                    if text.rawDetail.contains(word) { hit += 1.0 * lengthBoost }
                } else {
                    if text.title.contains(where: { matches($0, word) }) { hit += 4 }
                    if text.key.contains(where: { matches($0, word) }) || text.rawKey.hasPrefix(word) { hit += 3 }
                    if text.detail.contains(where: { matches($0, word) }) { hit += 1 }
                    if text.pane.contains(where: { matches($0, word) }) { hit += 1 }
                }
                if hit > 0 { matched += 1 }
                score += hit * (weights[word] ?? 0)
            }
            guard matched > 0 else { return nil }
            score *= 1 + Double(matched - 1) * 0.5
            if entry.title != nil { score *= 1.1 }
            return (entry, score)
        }
        let ranked = scored.sorted { $0.1 == $1.1 ? $0.0.displayTitle < $1.0.displayTitle : $0.1 > $1.1 }
        guard let best = ranked.first?.1 else { return [] }
        return ranked
            .prefix(limit)
            .filter { $0.1 >= best * 0.3 }
            .map(\.0)
    }

    private struct SearchText {
        let title: [String]
        let rawTitle: String
        let key: [String]
        let rawKey: String
        let detail: [String]
        let rawDetail: String
        let pane: [String]
        let rawPane: String

        func matches(_ word: String) -> Bool {
            if SettingsIndex.containsCJK(word) {
                return rawTitle.contains(word) || rawDetail.contains(word) || rawPane.contains(word)
            }
            return rawKey.hasPrefix(word) || [title, key, detail, pane].contains { $0.contains { SettingsIndex.matches($0, word) } }
        }
    }

    private static let endings: Set<Substring> = ["", "s", "es", "d", "ed", "ing", "r", "er", "ers", "ion", "ions", "ly"]

    private static func matches(_ indexed: String, _ word: String) -> Bool {
        indexed.hasPrefix(word) && endings.contains(indexed.dropFirst(word.count))
    }

    private static let searchText: [SearchText] = entries.map { entry in
        let paneJoined = entry.section.map { ([$0.label] + $0.searchTokens).joined(separator: " ") } ?? ""
        return SearchText(
            title: extractLatinWords(entry.displayTitle),
            rawTitle: entry.displayTitle.lowercased(),
            key: extractLatinWords(humanized(entry.key)),
            rawKey: entry.key.lowercased(),
            detail: extractLatinWords(entry.detail ?? ""),
            rawDetail: (entry.detail ?? "").lowercased(),
            pane: extractLatinWords(paneJoined),
            rawPane: paneJoined.lowercased()
        )
    }

    private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isCJKScalar)
    }

    private static func extractLatinWords(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for scalar in text.lowercased().unicodeScalars {
            if !isCJKScalar(scalar), CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func extractCJKTerms(_ text: String) -> [String] {
        var rawRuns: [String] = []
        var current = ""
        for scalar in text.unicodeScalars {
            if isCJKScalar(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                rawRuns.append(current)
                current = ""
            }
        }
        if !current.isEmpty { rawRuns.append(current) }

        var terms: [String] = []
        for run in rawRuns {
            var cleaned = run
            for phrase in cjkStopPhrases {
                cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
            }
            for part in cleaned.split(separator: " ").map(String.init) {
                let trimmed = part.trimmingCharacters(in: cjkSingleStopSet)
                guard !trimmed.isEmpty else { continue }
                if trimmed.count <= 4 {
                    terms.append(trimmed)
                }
                if trimmed.count >= 2 {
                    let chars = Array(trimmed)
                    for idx in 0..<(chars.count - 1) {
                        let bigram = String([chars[idx], chars[idx + 1]])
                        if !cjkStopWords.contains(bigram) {
                            terms.append(bigram)
                        }
                    }
                }
            }
        }
        return terms
    }

    private static func stem(_ word: String) -> String {
        word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") ? String(word.dropLast()) : word
    }

    private static let synonyms: [String: [String]] = [
        "smaller": ["width", "height", "size"], "bigger": ["width", "height", "size"], "larger": ["width", "height", "size"],
        "wider": ["width"], "narrower": ["width"], "taller": ["height"], "shorter": ["height"], "size": ["width", "height"],
        "dark": ["theme", "appearance"], "light": ["theme", "appearance"], "colour": ["color"],
        "login": ["launch"], "log": ["login", "launch"], "start": ["launch", "login"], "startup": ["launch", "login"], "boot": ["launch", "login"],
        "fahrenheit": ["temperature", "celsius", "unit"], "celsius": ["temperature", "unit"], "metric": ["unit"],
        "pomodoro": ["focus", "session"], "cpu": ["stats", "monitor", "readout"], "ram": ["memory", "stats"],
        "fullscreen": ["full", "screen"], "playing": ["music", "playback"], "song": ["music"], "songs": ["music"],
        "lyric": ["lyrics"], "sound": ["sound", "audio"], "noise": ["sound"], "hidden": ["hide"], "haptics": ["haptic"],
        "popup": ["hud"], "popups": ["hud"], "overlay": ["hud"],
        "unzip": ["extract", "extractor", "archive"], "zip": ["archive", "extract", "extractor"], "extract": ["archive", "extractor"],
        "sleep": ["caffeinate", "awake"], "sleeping": ["caffeinate", "awake"], "awake": ["caffeinate"],
        "kept": ["limit", "history"], "many": ["limit"], "save": ["power"],
        "dynamic": ["notch", "island"], "island": ["notch", "island"], "copy": ["clipboard"], "copied": ["clipboard"],
    ]

    private static let cjkSynonyms: [String: [String]] = [
        "刘海": ["灵动岛", "notch"],
        "灵动": ["灵动岛", "notch"],
        "防休眠": ["保持唤醒", "caffeinate"],
        "不休眠": ["保持唤醒", "caffeinate"],
        "常亮": ["保持唤醒", "caffeinate"],
        "开机": ["登录", "启动", "launch"],
        "自启": ["登录", "启动", "launch"],
        "自启动": ["登录", "启动", "launch"],
        "变小": ["宽度", "高度", "尺寸", "width", "height"],
        "调小": ["宽度", "高度", "尺寸", "width", "height"],
        "缩小": ["宽度", "高度", "尺寸", "width", "height"],
        "变大": ["宽度", "高度", "尺寸", "width", "height"],
        "调大": ["宽度", "高度", "尺寸", "width", "height"],
        "放大": ["宽度", "高度", "尺寸", "width", "height"],
        "大小": ["宽度", "高度", "尺寸", "width", "height"],
        "弹窗": ["hud", "浮层"],
        "浮窗": ["hud", "浮层"],
        "解压": ["归档", "压缩", "archive", "extractor"],
        "解压缩": ["归档", "压缩", "archive", "extractor"],
        "压缩包": ["归档", "压缩", "archive"],
        "分屏": ["磁吸", "分区", "snap"],
        "贴靠": ["磁吸", "分区", "snap"],
        "华氏": ["摄氏", "温度", "celsius", "weather"],
        "华氏度": ["摄氏", "温度", "celsius", "weather"],
        "番茄": ["专注", "focus"],
        "番茄钟": ["专注", "focus"],
        "保留": ["上限", "数量", "历史", "limit"],
        "条数": ["上限", "数量", "limit"],
    ]

    private static let cjkStopPhrases: [String] = [
        "在哪里", "怎么", "如何", "能不能", "能否", "可以", "请问", "帮我", "麻烦",
        "的时候", "时候", "设置项", "设置", "选项", "一下", "一点", "为什么", "是什么", "多少"
    ]

    private static let cjkStopWords: Set<String> = [
        "怎么", "如何", "可以", "能否", "设置", "选项", "一下", "一点", "什么", "多少"
    ]

    private static let cjkSingleStopSet = CharacterSet(charactersIn: "的了吗呢吧啊把将让给在从到与和或及中里时后")

    private static let stopWords: Set<String> = [
        "the", "a", "an", "to", "of", "in", "on", "off", "is", "it", "can", "i", "my", "me", "how", "do",
        "does", "and", "or", "for", "when", "with", "turn", "set", "make", "change", "enable", "disable",
        "want", "please", "could", "would", "should", "sapphire", "setting", "settings", "option", "there",
        "what", "which", "where", "some", "any", "suggest", "suggestion", "suggestions", "idea", "ideas",
        "recommend", "tips", "help", "you", "your", "im", "get", "use", "using", "way", "ways"
    ]

    // MARK: - Values

    static func value(of key: String, in settings: Settings) -> Value? {
        guard let dictionary = SettingsPersistence.encodeToDictionary(settings) else { return nil }
        return value(from: dictionary[key])
    }

    private static func value(from raw: Any?) -> Value? {
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(number.doubleValue)
        }
        if let text = raw as? String { return .text(text) }
        return nil
    }

    static func applying(key: String, rawValue: String, to settings: Settings) -> Result<(Settings, Change), ChangeError> {
        guard let entry = byKey[key] else { return .failure(.unknownSetting(key)) }
        guard var dictionary = SettingsPersistence.encodeToDictionary(settings),
              let current = value(from: dictionary[key]) else {
            return .failure(.unknownSetting(key))
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: Value
        switch current {
        case .bool:
            guard let on = parseBool(trimmed) else { return .failure(.invalidValue(key: key, expected: "开启或关闭（on / off）")) }
            newValue = .bool(on)
        case .number:
            guard var number = Double(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "%ptsx "))) else {
                return .failure(.invalidValue(key: key, expected: rangeDescription(entry) ?? "数字"))
            }
            if let range = entry.range { number = min(max(number, range.lowerBound), range.upperBound) }
            newValue = .number(number)
        case .text:
            if let options = entry.options {
                let normalized = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
                guard let match = options.first(where: { $0.lowercased().replacingOccurrences(of: " ", with: "") == normalized }) else {
                    return .failure(.invalidValue(key: key, expected: "以下选项之一：" + options.joined(separator: "、")))
                }
                newValue = .text(match)
            } else {
                newValue = .text(trimmed)
            }
        }

        var candidates = [newValue]
        if case .number(let number) = newValue, number.rounded() != number { candidates.append(.number(number.rounded())) }
        for candidate in candidates {
            switch candidate {
            case .bool(let on): dictionary[key] = on
            case .number(let number): dictionary[key] = number
            case .text(let text): dictionary[key] = text
            }
            if var updated = SettingsPersistence.decodeStrictly(dictionary),
               let stored = value(of: key, in: updated), stored == candidate || numericallyEqual(stored, candidate) {
                updated.applyDisplayDefaultToAllDisplays(key)
                return .success((updated, Change(entry: entry, oldValue: current, newValue: stored)))
            }
        }
        return .failure(.invalidValue(key: key, expected: rangeDescription(entry) ?? "有效值"))
    }

    static func rangeDescription(_ entry: Entry) -> String? {
        if let options = entry.options { return options.joined(separator: " / ") }
        guard let range = entry.range else { return nil }
        return "\(Value.number(range.lowerBound).description)–\(Value.number(range.upperBound).description)"
    }

    private static func numericallyEqual(_ lhs: Value, _ rhs: Value) -> Bool {
        if case .number(let a) = lhs, case .number(let b) = rhs { return abs(a - b) < 0.0001 }
        return false
    }

    private static func parseBool(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "true", "on", "yes", "1", "enable", "enabled", "show", "shown",
             "开", "开启", "打开", "启用", "是", "显示":
            return true
        case "false", "off", "no", "0", "disable", "disabled", "hide", "hidden",
             "关", "关闭", "关掉", "禁用", "停用", "否", "隐藏":
            return false
        default:
            return nil
        }
    }

    static func humanized(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for character in key {
            if character.isUppercase, !current.isEmpty, !(current.last?.isUppercase ?? false) {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        let sentence = words.map { $0.count > 1 && $0 == $0.uppercased() ? $0 : $0.lowercased() }.joined(separator: " ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }
}
