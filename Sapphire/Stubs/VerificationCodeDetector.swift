//
//  VerificationCodeDetector.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation

enum VerificationCodeDetector {
    private static let chineseTriggerKeywords: [String] = [
        "验证码", "校验码", "动态码", "确认码", "安全码",
        "认证码", "登录码", "提取码", "取件码", "动态密码",
        "一次性密码", "短信码", "口令"
    ]

    private static let englishTriggerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:verification\s+code|authentication\s+code|security\s+code|login\s+code|auth\s+code|one[-\s]?time\s+(?:password|code)|passcode|otp|2fa|mfa|verification)\b"#,
        options: [.caseInsensitive]
    )

    private static let channelBannerNoisePatterns: [String] = [
        "text channels)", "voice channels)", "(#general"
    ]

    private static let candidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])[A-Za-z]?-?(\d{4,8})(?![A-Za-z0-9])"#
    )

    static func find(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        let hasChineseTrigger = chineseTriggerKeywords.contains { trimmed.contains($0) }
        let fullNSRange = NSRange(trimmed.startIndex..., in: trimmed)
        let hasEnglishTrigger = englishTriggerRegex?.firstMatch(in: trimmed, range: fullNSRange) != nil

        // 因子一：必须具备明确的验证码语义触发词，杜绝把普通聊天/频道消息里的纯数字误判为验证码
        guard hasChineseTrigger || hasEnglishTrigger else { return nil }

        // 若来自 Discord/Slack 频道标题且没有任何中文或明确双词验证码短语，直接忽略
        if channelBannerNoisePatterns.contains(where: { lowered.contains($0) }),
           !hasChineseTrigger,
           !lowered.contains("verification code"),
           !lowered.contains("authentication code") {
            return nil
        }

        guard let regex = candidateRegex else { return nil }
        let matches = regex.matches(in: trimmed, range: fullNSRange)

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let digitsRange = Range(match.range(at: 1), in: trimmed),
                  let wholeRange = Range(match.range(at: 0), in: trimmed) else {
                continue
            }
            let code = String(trimmed[digitsRange])
            if isExcludedCandidate(code, wholeRange: wholeRange, digitsRange: digitsRange, in: trimmed) {
                continue
            }
            return code
        }

        return nil
    }

    private static func isExcludedCandidate(
        _ digits: String,
        wholeRange: Range<String.Index>,
        digitsRange: Range<String.Index>,
        in text: String
    ) -> Bool {
        // 因子二（排除规则）：剔除 4 位公历年份 (1990-2039)
        if digits.count == 4, let value = Int(digits), (1990...2039).contains(value) {
            return true
        }

        let beforeChar: Character? = wholeRange.lowerBound > text.startIndex
            ? text[text.index(before: wholeRange.lowerBound)]
            : nil
        let afterChar: Character? = digitsRange.upperBound < text.endIndex
            ? text[digitsRange.upperBound]
            : nil

        // 剔除时间格式 (14:30)、日期分隔 (2026/11)、小数/版本号前置点 (2.0000)、井号频道/订单 (#894210)
        if let beforeChar, [":", "/", ".", "#", "$", "¥", "￥", "€", "£"].contains(beforeChar) {
            return true
        }
        if let afterChar {
            if [":", "/", "%", "年", "月", "日", "元", "室", "楼", "号"].contains(afterChar) {
                return true
            }
            // 仅当句点后紧跟数字（如 12.3456）时才视作小数/版本号剔除，保留英文句末句号（如 739182.）
            if afterChar == "." {
                let nextIdx = text.index(after: digitsRange.upperBound)
                if nextIdx < text.endIndex, text[nextIdx].isNumber {
                    return true
                }
            }
        }

        // 剔除 PR / Issue / Order 编号上下文
        let prefixStart = text.index(wholeRange.lowerBound, offsetBy: -8, limitedBy: text.startIndex) ?? text.startIndex
        let prefixWindow = text[prefixStart..<wholeRange.lowerBound].lowercased()
        if prefixWindow.hasSuffix("pr ") || prefixWindow.hasSuffix("issue ") || prefixWindow.hasSuffix("order ") {
            return true
        }

        return false
    }
}
#endif
