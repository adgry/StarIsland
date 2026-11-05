import AppKit
import Combine
import CoreBluetooth
import EventKit
import Foundation
import IOKit
import IslandCore

public enum MeetingProvider: String, Codable, Equatable, Sendable {
    case zoom
    case tencentMeeting
    case feishu
    case googleMeet
    case teams
    case webex

    public var displayName: String {
        switch self {
        case .zoom: return "Zoom 会议"
        case .tencentMeeting: return "腾讯会议"
        case .feishu: return "飞书会议"
        case .googleMeet: return "Google Meet"
        case .teams: return "Teams 会议"
        case .webex: return "Webex 会议"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .zoom, .tencentMeeting, .feishu, .googleMeet, .teams, .webex:
            return "video.fill"
        }
    }
}

public enum MeetingLinkExtractor {
    private static let urlRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+"#,
            options: [.caseInsensitive]
        )
    }()

    private static let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)'\"\\]>")

    public static func extractJoinURL(from text: String) -> URL? {
        detectMeeting(in: text)?.url
    }

    public static func detectMeeting(in text: String) -> (provider: MeetingProvider, url: URL)? {
        guard !text.isEmpty, let regex = urlRegex else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            var candidate = String(text[range])
            while let lastScalar = candidate.unicodeScalars.last,
                  trailingPunctuation.contains(lastScalar) {
                candidate.removeLast()
            }

            guard let url = URL(string: candidate),
                  let host = url.host?.lowercased() else {
                continue
            }

            if let provider = classifyProvider(host: host, path: url.path.lowercased()) {
                return (provider, url)
            }
        }
        return nil
    }

    private static func classifyProvider(host: String, path: String) -> MeetingProvider? {
        if host == "zoom.us" || host.hasSuffix(".zoom.us") || host == "zoom.com.cn" || host.hasSuffix(".zoom.com.cn") {
            return .zoom
        }
        if host == "meeting.tencent.com" || host.hasSuffix(".meeting.tencent.com")
            || host == "voovmeeting.com" || host.hasSuffix(".voovmeeting.com")
            || host == "wemeet.qq.com" {
            return .tencentMeeting
        }
        if host == "vc.feishu.cn" || host == "vc.larksuite.com"
            || ((host.hasSuffix(".feishu.cn") || host.hasSuffix(".larksuite.com")) && path.contains("/j/")) {
            return .feishu
        }
        if host == "meet.google.com" {
            return .googleMeet
        }
        if host == "teams.microsoft.com" || host == "teams.live.com" {
            return .teams
        }
        if host == "webex.com" || host.hasSuffix(".webex.com") {
            return .webex
        }
        return nil
    }
}

public struct UpcomingCalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarTitle: String
    public let location: String?
    public let joinURL: URL?
    public let meetingProvider: MeetingProvider?

    public func minutesUntilStart(from now: Date = Date()) -> Int {
        Int((startDate.timeIntervalSince(now) / 60.0).rounded())
    }
}

public struct ReminderTodoItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let dueDate: Date?
    public var isCompleted: Bool
    public let listTitle: String
}

public struct ConnectedBluetoothDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbolName: String
    public let batteryPercent: Int?
    public let leftEarPercent: Int?
    public let rightEarPercent: Int?
    public let casePercent: Int?

    public var displayBatteryText: String {
        if let left = leftEarPercent, let right = rightEarPercent {
            if let casePct = casePercent {
                return "左\(left)% · 右\(right)% · 盒\(casePct)%"
            }
            return "左\(left)% · 右\(right)%"
        }
        if let pct = batteryPercent {
            return "\(pct)%"
        }
        return "已连接"
    }

    public var primaryPercent: Int {
        if let pct = batteryPercent { return pct }
        if let left = leftEarPercent, let right = rightEarPercent { return min(left, right) }
        return leftEarPercent ?? rightEarPercent ?? 100
    }
}

@MainActor
public final class CalendarBluetoothService: NSObject, ObservableObject, CBCentralManagerDelegate {
    public static let shared = CalendarBluetoothService()

    @Published public private(set) var todayEvents: [UpcomingCalendarEvent] = []
    @Published public private(set) var reminders: [ReminderTodoItem] = []
    @Published public private(set) var bluetoothDevices: [ConnectedBluetoothDevice] = []
    @Published public private(set) var hasCalendarAccess: Bool = false
    @Published public private(set) var hasRemindersAccess: Bool = false

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let eventStore = EKEventStore()
    private var centralManager: CBCentralManager?
    private var refreshTask: Task<Void, Never>?
    private var notifiedEventIDs: Set<String> = []

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        super.init()
        updateAuthorizationStates()
    }

    public func startMonitoring(interval: TimeInterval = 60) {
        if centralManager == nil && settingsStore.settings.enableBluetoothBatteryWidget {
            centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshAll()
                try? await Task.sleep(nanoseconds: UInt64(max(20.0, interval) * 1_000_000_000))
            }
        }
    }

    public func stopMonitoring() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func requestCalendarAndRemindersAccess() async {
        if settingsStore.settings.enableCalendarWidget {
            _ = try? await eventStore.requestFullAccessToEvents()
        }
        if settingsStore.settings.enableRemindersWidget {
            _ = try? await eventStore.requestFullAccessToReminders()
        }
        updateAuthorizationStates()
        await refreshAll()
    }

    public func refreshAll() async {
        updateAuthorizationStates()
        if settingsStore.settings.enableCalendarWidget && hasCalendarAccess {
            loadTodayEvents()
        }
        if settingsStore.settings.enableRemindersWidget && hasRemindersAccess {
            await loadIncompleteReminders()
        }
        if settingsStore.settings.enableBluetoothBatteryWidget {
            await refreshBluetoothDevices()
        }
    }

    public func joinMeeting(_ event: UpcomingCalendarEvent) {
        guard let url = event.joinURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func toggleReminderCompletion(_ item: ReminderTodoItem) async {
        guard hasRemindersAccess,
              let calendarItem = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
            return
        }
        calendarItem.isCompleted.toggle()
        calendarItem.completionDate = calendarItem.isCompleted ? Date() : nil
        try? eventStore.save(calendarItem, commit: true)
        await loadIncompleteReminders()
    }

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        Task { @MainActor [weak self] in
            await self?.refreshBluetoothDevices()
        }
    }

    private func updateAuthorizationStates() {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        hasCalendarAccess = (eventStatus == .fullAccess)
        hasRemindersAccess = (reminderStatus == .fullAccess)
    }

    private func loadTodayEvents() {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .hour, value: 30, to: now) ?? now.addingTimeInterval(86_400)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        var mapped: [UpcomingCalendarEvent] = []
        for ek in ekEvents.prefix(8) {
            let combinedText = [ek.url?.absoluteString, ek.location, ek.notes]
                .compactMap { $0 }
                .joined(separator: "\n")
            let detected = MeetingLinkExtractor.detectMeeting(in: combinedText)
            let eventItem = UpcomingCalendarEvent(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: ek.title?.isEmpty == false ? ek.title! : "未命名日程",
                startDate: ek.startDate,
                endDate: ek.endDate,
                isAllDay: ek.isAllDay,
                calendarTitle: ek.calendar.title,
                location: ek.location,
                joinURL: detected?.url,
                meetingProvider: detected?.provider
            )
            mapped.append(eventItem)

            // 临近 10 分钟开会灵动岛提醒
            let mins = eventItem.minutesUntilStart(from: now)
            if !eventItem.isAllDay && (0...10).contains(mins) && !notifiedEventIDs.contains(eventItem.id) {
                notifiedEventIDs.insert(eventItem.id)
                stateMachine.submit(
                    IslandActivityItem(
                        id: "calendar.upcoming.\(eventItem.id)",
                        category: .timer,
                        title: eventItem.title,
                        subtitle: mins <= 0 ? "会议现在开始" : "\(mins) 分钟后开始",
                        iconSymbol: eventItem.meetingProvider?.iconSymbol ?? "calendar.badge.clock",
                        trailingBadge: eventItem.meetingProvider?.displayName,
                        priority: .interactive,
                        isPeek: true,
                        autoDismissAfter: 6.0,
                        actionTitle: eventItem.joinURL != nil ? "一键入会" : nil,
                        actionPayload: eventItem.joinURL?.absoluteString
                    )
                )
            }
        }
        todayEvents = mapped
    }

    private func loadIncompleteReminders() async {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        let fetched: [ReminderTodoItem] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { list in
                let items = (list ?? []).prefix(10).map { rem in
                    ReminderTodoItem(
                        id: rem.calendarItemIdentifier,
                        title: rem.title.isEmpty ? "未命名提醒" : rem.title,
                        dueDate: rem.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                        isCompleted: rem.isCompleted,
                        listTitle: rem.calendar.title
                    )
                }
                continuation.resume(returning: Array(items))
            }
        }
        reminders = fetched
    }

    private func refreshBluetoothDevices() async {
        var collected = Self.readIOKitHIDBatteryDevices()
        let profilerDevices = await Task.detached(priority: .utility) {
            Self.readSystemProfilerBluetoothDevices()
        }.value

        let existingNames = Set(collected.map { $0.name.lowercased() })
        for dev in profilerDevices where !existingNames.contains(dev.name.lowercased()) {
            collected.append(dev)
        }

        if let centralManager, centralManager.state == .poweredOn {
            let blePeripherals = centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: "180F")])
            for peripheral in blePeripherals {
                let name = peripheral.name ?? "蓝牙外设"
                if !collected.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                    collected.append(
                        ConnectedBluetoothDevice(
                            id: peripheral.identifier.uuidString,
                            name: name,
                            symbolName: Self.symbolForDeviceName(name),
                            batteryPercent: nil,
                            leftEarPercent: nil,
                            rightEarPercent: nil,
                            casePercent: nil
                        )
                    )
                }
            }
        }

        bluetoothDevices = collected
    }

    nonisolated private static func readIOKitHIDBatteryDevices() -> [ConnectedBluetoothDevice] {
        var results: [ConnectedBluetoothDevice] = []
        guard let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") else {
            return results
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return results
        }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = propsRef?.takeRetainedValue() as? [String: Any],
                  let product = dict["Product"] as? String,
                  let percent = dict["BatteryPercent"] as? Int else {
                continue
            }
            let serial = (dict["SerialNumber"] as? String) ?? product
            results.append(
                ConnectedBluetoothDevice(
                    id: "iokit-\(serial)",
                    name: product,
                    symbolName: symbolForDeviceName(product),
                    batteryPercent: max(0, min(100, percent)),
                    leftEarPercent: nil,
                    rightEarPercent: nil,
                    casePercent: nil
                )
            )
        }
        return results
    }

    nonisolated private static func readSystemProfilerBluetoothDevices() -> [ConnectedBluetoothDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else {
            return []
        }

        var devices: [ConnectedBluetoothDevice] = []
        for item in controllers {
            guard let connectedArray = item["device_connected"] as? [[String: Any]] else { continue }
            for deviceEntry in connectedArray {
                for (name, rawInfo) in deviceEntry {
                    guard let info = rawInfo as? [String: Any] else { continue }
                    let mainPct = parsePercentString(info["device_batteryLevelMain"] as? String)
                    let leftPct = parsePercentString(info["device_batteryLevelLeft"] as? String)
                    let rightPct = parsePercentString(info["device_batteryLevelRight"] as? String)
                    let casePct = parsePercentString(info["device_batteryLevelCase"] as? String)
                    let addr = (info["device_address"] as? String) ?? name
                    devices.append(
                        ConnectedBluetoothDevice(
                            id: "bt-\(addr)",
                            name: name,
                            symbolName: symbolForDeviceName(name),
                            batteryPercent: mainPct,
                            leftEarPercent: leftPct,
                            rightEarPercent: rightPct,
                            casePercent: casePct
                        )
                    )
                }
            }
        }
        return devices
    }

    nonisolated private static func parsePercentString(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = raw.filter(\.isNumber)
        guard let val = Int(digits) else { return nil }
        return max(0, min(100, val))
    }

    nonisolated private static func symbolForDeviceName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") || lower.contains("headphone") || lower.contains("sony") || lower.contains("bose") {
            return "headphones"
        }
        if lower.contains("airpods") || lower.contains("buds") {
            return "airpodspro"
        }
        if lower.contains("keyboard") || lower.contains("键盘") {
            return "keyboard.fill"
        }
        if lower.contains("trackpad") || lower.contains("触控板") {
            return "rectangle.and.hand.point.up.left.fill"
        }
        if lower.contains("mouse") || lower.contains("鼠标") {
            return "magicmouse.fill"
        }
        return "dot.radiowaves.left.and.right"
    }
}
