import AppKit
import Combine
import Foundation
import IslandCore

public struct DetectedOTP: Equatable, Codable, Identifiable, Sendable {
    public var id: String { fingerprint }
    public let code: String
    public let sourceAppBundleID: String
    public let senderOrTitle: String
    public let messagePreview: String
    public let fingerprint: String
    public let detectedAt: Date

    public init(
        code: String,
        sourceAppBundleID: String,
        senderOrTitle: String,
        messagePreview: String,
        fingerprint: String,
        detectedAt: Date = Date()
    ) {
        self.code = code
        self.sourceAppBundleID = sourceAppBundleID
        self.senderOrTitle = senderOrTitle
        self.messagePreview = messagePreview
        self.fingerprint = fingerprint
        self.detectedAt = detectedAt
    }
}

public struct DetectedParcel: Equatable, Codable, Identifiable, Sendable {
    public var id: String { "\(carrierCode):\(trackingNumber)" }
    public let trackingNumber: String
    public let carrierCode: String
    public let carrierName: String
    public let queryURL: URL?
    public let detectedAt: Date

    public init(
        trackingNumber: String,
        carrierCode: String,
        carrierName: String,
        queryURL: URL?,
        detectedAt: Date = Date()
    ) {
        self.trackingNumber = trackingNumber
        self.carrierCode = carrierCode
        self.carrierName = carrierName
        self.queryURL = queryURL
        self.detectedAt = detectedAt
    }
}

public enum SmartCodeDetector {
    private static let semanticRegex: NSRegularExpression = {
        let zh = "验证码|校验码|动态码|确认码|安全码|认证码|登录码|提取码|动态口令|安全口令|验证口令|口令"
        let en = #"\b(?:verification|verify|passcode|otp|auth(?:entication)?\s*code|security\s*code|login\s*code|confirmation\s*code|two-factor|2fa|one-time(?:\s*(?:password|code))?)\b"#
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: "(?:\(zh)|\(en))", options: [.caseInsensitive])
    }()

    private static let candidateTokenRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9])[A-Za-z0-9]{4,8}(?![A-Za-z0-9])"#, options: [])
    }()

    private static let excludedPrefixes: [String] = [
        "¥", "￥", "$", "€", "£", "rmb", "cny", "usd", "hkd",
        "消费", "金额", "支付", "付款", "收款", "余额", "转账", "总计", "合计", "人民币",
        "尾号", "末四位", "后四位", "卡号", "订单", "端口", "port"
    ]

    private static let excludedSuffixes: [String] = [
        "元", "块", "角", "分", "分钟", "秒", "小时", "天", "日", "月", "年",
        "次", "个", "条", "位", "折", "kb", "mb", "gb", "tb", "hz", "px", "pt"
    ]

    public static func detectOTP(
        title: String,
        body: String,
        appBundleID: String = "",
        now: Date = Date()
    ) -> DetectedOTP? {
        let combined = title.isEmpty ? body : "\(title)\n\(body)"
        let combinedNS = combined as NSString
        let fullRange = NSRange(location: 0, length: combinedNS.length)

        let keywordMatches = semanticRegex.matches(in: combined, options: [], range: fullRange)
        guard !keywordMatches.isEmpty else {
            return nil
        }

        let bodyCandidate = bestCandidate(in: body, keywordLocations: keywordPositions(in: body), baseBoost: 50)
        let titleCandidate = bestCandidate(in: title, keywordLocations: keywordPositions(in: title), baseBoost: 0)

        let chosenCode: String?
        switch (bodyCandidate, titleCandidate) {
        case let (b?, t?):
            chosenCode = b.score >= t.score ? b.code : t.code
        case let (b?, nil):
            chosenCode = b.code
        case let (nil, t?):
            chosenCode = t.code
        case (nil, nil):
            chosenCode = nil
        }

        guard let code = chosenCode else {
            return nil
        }

        let fingerprint = ConsumedEventStore.sha256Hex("\(appBundleID)|\(title)|\(body)|\(code)")
        let preview = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return DetectedOTP(
            code: code,
            sourceAppBundleID: appBundleID,
            senderOrTitle: title,
            messagePreview: String(preview.prefix(120)),
            fingerprint: fingerprint,
            detectedAt: now
        )
    }

    private static func keywordPositions(in text: String) -> [NSRange] {
        guard !text.isEmpty else { return [] }
        let ns = text as NSString
        return semanticRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)).map(\.range)
    }

    private static func bestCandidate(
        in text: String,
        keywordLocations: [NSRange],
        baseBoost: Int
    ) -> (code: String, score: Int)? {
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        let matches = candidateTokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var best: (code: String, score: Int)?

        for match in matches {
            let range = match.range
            let token = ns.substring(with: range)
            guard isValidOTPToken(token, in: ns, range: range) else {
                continue
            }

            var score = baseBoost
            let allDigits = token.allSatisfy(\.isNumber)
            if allDigits {
                score += (token.count == 6) ? 45 : 30
            } else {
                score += 15
            }

            for kw in keywordLocations {
                let kwEnd = kw.location + kw.length
                if range.location >= kwEnd {
                    let distance = range.location - kwEnd
                    if distance <= 36 {
                        score += max(10, 70 - distance * 2)
                    }
                } else if kw.location >= range.location + range.length {
                    let distance = kw.location - (range.location + range.length)
                    if distance <= 20 {
                        score += max(8, 45 - distance * 2)
                    }
                }
            }

            if best == nil || score > best!.score {
                best = (token, score)
            }
        }

        return best
    }

    private static func isValidOTPToken(_ token: String, in ns: NSString, range: NSRange) -> Bool {
        // 仅允许纯数字或全大写字母+数字组合，且至少包含 2 位数字，避免误匹配普通英文单词
        var digitCount = 0
        for ch in token {
            if ch.isNumber {
                digitCount += 1
            } else if !(ch.isASCII && ch.isUppercase) {
                return false
            }
        }
        guard digitCount >= 2 else { return false }

        // 排除 4 位年份（2020-2035 及常见公历年份 1990-2040）
        if token.count == 4, digitCount == 4, let year = Int(token), (1990...2040).contains(year) {
            return false
        }

        let start = range.location
        let end = range.location + range.length

        // 排除小数点金额（如 1280.50）与时间冒号连接符（如 14:30）
        if start > 0 {
            let prevChar = ns.substring(with: NSRange(location: start - 1, length: 1))
            if prevChar == ":" || prevChar == "：" || prevChar == "-" || prevChar == "/" {
                if prevChar == ":" || prevChar == "：" { return false }
            }
            if prevChar == ".", start > 1 {
                let beforeDot = ns.substring(with: NSRange(location: start - 2, length: 1))
                if beforeDot.first?.isNumber == true { return false }
            }
        }
        if end < ns.length {
            let nextChar = ns.substring(with: NSRange(location: end, length: 1))
            if nextChar == ":" || nextChar == "：" {
                return false
            }
            if nextChar == ".", end + 1 < ns.length {
                let afterDot = ns.substring(with: NSRange(location: end + 1, length: 1))
                if afterDot.first?.isNumber == true { return false }
            }
        }

        // 检查前缀（货币符号、金额词汇、银行卡尾号、端口号等）
        let prefixLen = min(10, start)
        if prefixLen > 0 {
            let rawPrefix = ns.substring(with: NSRange(location: start - prefixLen, length: prefixLen))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let cleanedPrefix = rawPrefix.trimmingCharacters(in: CharacterSet(charactersIn: ":：=is为是"))
                .trimmingCharacters(in: .whitespaces)
            for p in excludedPrefixes {
                if rawPrefix.hasSuffix(p) || cleanedPrefix.hasSuffix(p) {
                    return false
                }
            }
        }

        // 检查后缀（元、分钟、年、月、日等单位）
        let suffixLen = min(6, ns.length - end)
        if suffixLen > 0 {
            let rawSuffix = ns.substring(with: NSRange(location: end, length: suffixLen))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            for s in excludedSuffixes where rawSuffix.hasPrefix(s) {
                return false
            }
        }

        return true
    }

    // MARK: - 快递物流单号识别

    private struct CarrierRule {
        let code: String
        let name: String
        let pattern: String
        let contextKeywords: [String]
        let queryTemplate: String
    }

    private static let carrierRules: [CarrierRule] = [
        .init(
            code: "sf",
            name: "顺丰速运",
            pattern: #"(?<![A-Za-z0-9])SF\d{13}(?![A-Za-z0-9])"#,
            contextKeywords: [],
            queryTemplate: "https://www.sf-express.com/chn/sc/dynamic_function/waybill/#search/bill-number/%@"
        ),
        .init(
            code: "ups",
            name: "UPS",
            pattern: #"(?<![A-Za-z0-9])1Z[A-Z0-9]{16}(?![A-Za-z0-9])"#,
            contextKeywords: [],
            queryTemplate: "https://www.ups.com/track?tracknum=%@"
        ),
        .init(
            code: "jd",
            name: "京东物流",
            pattern: #"(?<![A-Za-z0-9])JD[A-Z0-9]{11,15}(?![A-Za-z0-9])"#,
            contextKeywords: [],
            queryTemplate: "https://www.jdl.com/orderSearch?waybillCodes=%@"
        ),
        .init(
            code: "yto",
            name: "圆通速递",
            pattern: #"(?<![A-Za-z0-9])YT\d{13}(?![A-Za-z0-9])"#,
            contextKeywords: [],
            queryTemplate: "https://www.kuaidi100.com/chaxun?com=yuantong&nu=%@"
        ),
        .init(
            code: "ems",
            name: "中国邮政 EMS",
            pattern: #"(?<![A-Za-z0-9])E[A-Z]\d{9}[A-Z]{2}(?![A-Za-z0-9])"#,
            contextKeywords: [],
            queryTemplate: "https://www.ems.com.cn/queryList?emsFollow=%@"
        ),
        .init(
            code: "sto",
            name: "申通快递",
            pattern: #"(?<![A-Za-z0-9])77\d{13}(?![A-Za-z0-9])"#,
            contextKeywords: ["申通", "快递", "运单", "包裹", "单号"],
            queryTemplate: "https://www.kuaidi100.com/chaxun?com=shentong&nu=%@"
        ),
        .init(
            code: "zto",
            name: "中通快递",
            pattern: #"(?<![A-Za-z0-9])7[358]\d{12}(?![A-Za-z0-9])"#,
            contextKeywords: ["中通", "快递", "运单", "包裹", "单号"],
            queryTemplate: "https://www.kuaidi100.com/chaxun?com=zhongtong&nu=%@"
        ),
        .init(
            code: "yd",
            name: "韵达快递",
            pattern: #"(?<![A-Za-z0-9])4[36]\d{13}(?![A-Za-z0-9])"#,
            contextKeywords: ["韵达", "快递", "运单", "包裹", "单号"],
            queryTemplate: "https://www.kuaidi100.com/chaxun?com=yunda&nu=%@"
        ),
        .init(
            code: "fedex",
            name: "FedEx 联邦快递",
            pattern: #"(?<![A-Za-z0-9])(?:\d{12}|\d{15}|96\d{18,20})(?![A-Za-z0-9])"#,
            contextKeywords: ["fedex", "联邦快递"],
            queryTemplate: "https://www.fedex.com/fedextrack/?trknbr=%@"
        ),
        .init(
            code: "dhl",
            name: "DHL",
            pattern: #"(?<![A-Za-z0-9])(?:JJD\d{10,18}|\d{10})(?![A-Za-z0-9])"#,
            contextKeywords: ["dhl"],
            queryTemplate: "https://www.dhl.com/cn-zh/home/tracking.html?tracking-id=%@"
        ),
    ]

    public static func detectParcel(in text: String, now: Date = Date()) -> DetectedParcel? {
        guard !text.isEmpty else { return nil }
        let lowerText = text.lowercased()
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        for rule in carrierRules {
            if !rule.contextKeywords.isEmpty {
                let hasContext = rule.contextKeywords.contains { lowerText.contains($0.lowercased()) }
                guard hasContext else { continue }
            }
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, options: [], range: fullRange) else {
                continue
            }
            let tracking = ns.substring(with: match.range).uppercased()
            let urlString = String(format: rule.queryTemplate, tracking)
            return DetectedParcel(
                trackingNumber: tracking,
                carrierCode: rule.code,
                carrierName: rule.name,
                queryURL: URL(string: urlString),
                detectedAt: now
            )
        }
        return nil
    }
}

@MainActor
public final class SmartInboxCoordinator: ObservableObject {
    public static let shared = SmartInboxCoordinator()

    @Published public private(set) var recentOTPs: [DetectedOTP] = []
    @Published public private(set) var recentParcels: [DetectedParcel] = []
    @Published public private(set) var lastCopiedCode: String?

    private let consumedStore: ConsumedEventStore
    private let stateMachine: IslandStateMachine
    private let settingsStore: SettingsStore
    private let pasteboardWriter: (String) -> Void

    public init(
        consumedStore: ConsumedEventStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil,
        pasteboardWriter: ((String) -> Void)? = nil
    ) {
        self.consumedStore = consumedStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        self.settingsStore = settingsStore ?? .shared
        self.pasteboardWriter = pasteboardWriter ?? { code in
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(code, forType: .string)
            pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        }
    }

    @discardableResult
    public func ingestNotification(
        appBundleID: String,
        appName: String = "",
        title: String,
        body: String,
        now: Date = Date()
    ) -> Bool {
        if settingsStore.settings.enableSmartOTP,
           let otp = SmartCodeDetector.detectOTP(title: title, body: body, appBundleID: appBundleID, now: now) {
            // 先落盘后展示契约：若该验证码事件指纹已消费，严格丢弃，绝不二次弹窗
            guard consumedStore.tryConsume(fingerprint: otp.fingerprint, now: now) else {
                return false
            }

            recentOTPs.removeAll { $0.code == otp.code && $0.sourceAppBundleID == otp.sourceAppBundleID }
            recentOTPs.insert(otp, at: 0)
            if recentOTPs.count > 20 {
                recentOTPs.removeLast(recentOTPs.count - 20)
            }

            let autoCopied = settingsStore.settings.autoCopyOTP
            if autoCopied {
                pasteboardWriter(otp.code)
                lastCopiedCode = otp.code
            }

            let sourceLabel = appName.isEmpty ? (title.isEmpty ? "智能通知" : title) : appName
            let subtitleText = autoCopied ? "\(sourceLabel) · 已自动复制到剪贴板" : "\(sourceLabel) · 点击复制后自动收起"
            let activity = IslandActivityItem(
                id: "otp-\(otp.fingerprint.prefix(12))",
                category: .otp,
                title: "验证码 \(otp.code)",
                subtitle: subtitleText,
                iconSymbol: "key.horizontal.fill",
                trailingBadge: autoCopied ? "已复制" : "复制",
                priority: .urgent,
                isAlertHUD: true,
                allowsOnLockScreen: false,
                autoDismissAfter: 6.0,
                actionTitle: "复制验证码",
                actionPayload: otp.code,
                updatedAt: now
            )
            stateMachine.submit(activity)
            return true
        }

        if settingsStore.settings.enableParcelTracking {
            let fullText = title.isEmpty ? body : "\(title)\n\(body)"
            if let parcel = SmartCodeDetector.detectParcel(in: fullText, now: now) {
                let fp = ConsumedEventStore.sha256Hex("parcel|\(appBundleID)|\(parcel.id)|\(body)")
                guard consumedStore.tryConsume(fingerprint: fp, now: now) else {
                    return false
                }

                recentParcels.removeAll { $0.id == parcel.id }
                recentParcels.insert(parcel, at: 0)
                if recentParcels.count > 20 {
                    recentParcels.removeLast(recentParcels.count - 20)
                }

                let activity = IslandActivityItem(
                    id: "parcel-\(parcel.carrierCode)-\(parcel.trackingNumber.suffix(6))",
                    category: .otp,
                    title: "\(parcel.carrierName) \(parcel.trackingNumber)",
                    subtitle: "已识别物流单号，可在效率看板一键查件",
                    iconSymbol: "shippingbox.fill",
                    trailingBadge: "查物流",
                    priority: .interactive,
                    isPeek: true,
                    allowsOnLockScreen: false,
                    autoDismissAfter: 4.5,
                    actionTitle: "查询物流",
                    actionPayload: parcel.queryURL?.absoluteString ?? parcel.trackingNumber,
                    updatedAt: now
                )
                stateMachine.submit(activity)
                return true
            }
        }

        return false
    }

    public func copyOTPAndCollapse(_ code: String, activityID: String? = nil) {
        pasteboardWriter(code)
        lastCopiedCode = code
        if let activityID {
            stateMachine.dismiss(id: activityID)
        } else {
            stateMachine.clearCategory(.otp)
        }
        stateMachine.collapseExpanded()
    }

    public func openParcelTracking(_ parcel: DetectedParcel) {
        if let url = parcel.queryURL {
            NSWorkspace.shared.open(url)
        }
    }

    public func clearHistory() {
        recentOTPs.removeAll()
        recentParcels.removeAll()
    }
}
