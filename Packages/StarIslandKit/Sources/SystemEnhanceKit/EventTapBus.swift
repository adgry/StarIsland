import ApplicationServices
import CoreGraphics
import Foundation

/// 全局事件总线处理结果
public enum EventTapDisposition: Equatable {
    /// 原样放行事件，继续传递给后续低优先级处理器与系统
    case passThrough
    /// 拦截并吞掉事件，立即短路后续处理器且不投递给目标应用
    case suppress
    /// 使用修改/合成后的新 CGEvent 替换原事件
    case replace(CGEvent)

    public static func == (lhs: EventTapDisposition, rhs: EventTapDisposition) -> Bool {
        switch (lhs, rhs) {
        case (.passThrough, .passThrough), (.suppress, .suppress):
            return true
        case (.replace(let lhsEvent), .replace(let rhsEvent)):
            return lhsEvent === rhsEvent
        default:
            return false
        }
    }
}

/// 传递给各增强模块的事件上下文快照
public struct EventTapContext {
    public let eventType: CGEventType
    public var cgEvent: CGEvent?
    public let keyCode: Int64
    public let flags: CGEventFlags
    public let mouseButtonNumber: Int64
    public let isAutoRepeat: Bool
    public let scrollIsContinuous: Bool
    public let scrollDeltaAxis1: Int64
    public let location: CGPoint
    public let timestampNs: UInt64
    public let unicodeCharacters: String

    public init(
        eventType: CGEventType,
        cgEvent: CGEvent? = nil,
        keyCode: Int64 = 0,
        flags: CGEventFlags = [],
        mouseButtonNumber: Int64 = 0,
        isAutoRepeat: Bool = false,
        scrollIsContinuous: Bool = false,
        scrollDeltaAxis1: Int64 = 0,
        location: CGPoint = .zero,
        timestampNs: UInt64 = DispatchTime.now().uptimeNanoseconds,
        unicodeCharacters: String = ""
    ) {
        self.eventType = eventType
        self.cgEvent = cgEvent
        self.keyCode = keyCode
        self.flags = flags
        self.mouseButtonNumber = mouseButtonNumber
        self.isAutoRepeat = isAutoRepeat
        self.scrollIsContinuous = scrollIsContinuous
        self.scrollDeltaAxis1 = scrollDeltaAxis1
        self.location = location
        self.timestampNs = timestampNs
        self.unicodeCharacters = unicodeCharacters
    }

    public init(eventType: CGEventType, cgEvent: CGEvent) {
        self.eventType = eventType
        self.cgEvent = cgEvent
        self.keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)
        self.flags = cgEvent.flags
        self.mouseButtonNumber = cgEvent.getIntegerValueField(.mouseEventButtonNumber)
        self.isAutoRepeat = cgEvent.getIntegerValueField(.keyboardEventAutorepeat) != 0
        self.scrollIsContinuous = cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        self.scrollDeltaAxis1 = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        self.location = cgEvent.location
        self.timestampNs = UInt64(cgEvent.timestamp)

        if eventType == .keyDown || eventType == .keyUp {
            var actualLength: Int = 0
            var utf16Buffer = [UniChar](repeating: 0, count: 16)
            cgEvent.keyboardGetUnicodeString(
                maxStringLength: utf16Buffer.count,
                actualStringLength: &actualLength,
                unicodeString: &utf16Buffer
            )
            if actualLength > 0 {
                self.unicodeCharacters = String(utf16CodeUnits: utf16Buffer, count: actualLength)
            } else {
                self.unicodeCharacters = ""
            }
        } else {
            self.unicodeCharacters = ""
        }
    }
}

/// 单个事件拦截处理器注册项
public struct EventTapEntry {
    public let id: UUID
    public let name: String
    public let priority: Int
    public let eventMask: CGEventMask
    public let handler: (EventTapContext) -> EventTapDisposition

    public init(
        id: UUID = UUID(),
        name: String,
        priority: Int,
        eventMask: CGEventMask,
        handler: @escaping (EventTapContext) -> EventTapDisposition
    ) {
        self.id = id
        self.name = name
        self.priority = priority
        self.eventMask = eventMask
        self.handler = handler
    }

    /// 将一组 CGEventType 安全合并为 64 位事件掩码
    public static func mask(for types: [CGEventType]) -> CGEventMask {
        var maskValue: CGEventMask = 0
        for type in types {
            let raw = type.rawValue
            guard raw < 64 else { continue }
            maskValue |= ((1 as CGEventMask) << CGEventMask(raw))
        }
        return maskValue
    }

    /// 检查当前处理器是否关注给定事件类型
    public func matches(_ type: CGEventType) -> Bool {
        let raw = type.rawValue
        guard raw < 64 else { return false }
        let bit = (1 as CGEventMask) << CGEventMask(raw)
        return (eventMask & bit) != 0
    }
}

/// 事件总线运行统计快照
public struct EventTapStatistics: Equatable, Sendable {
    public var registeredHandlers: Int
    public var isTapActive: Bool
    public var dispatchedEvents: UInt64
    public var suppressedEvents: UInt64
    public var replacedEvents: UInt64
    public var timeoutRecoveries: UInt64

    public init(
        registeredHandlers: Int = 0,
        isTapActive: Bool = false,
        dispatchedEvents: UInt64 = 0,
        suppressedEvents: UInt64 = 0,
        replacedEvents: UInt64 = 0,
        timeoutRecoveries: UInt64 = 0
    ) {
        self.registeredHandlers = registeredHandlers
        self.isTapActive = isTapActive
        self.dispatchedEvents = dispatchedEvents
        self.suppressedEvents = suppressedEvents
        self.replacedEvents = replacedEvents
        self.timeoutRecoveries = timeoutRecoveries
    }
}

/// 进程级唯一 CGEventTap 调度总线：
/// - 按优先级从高到低链式执行处理器，遇到 `.suppress` 立即短路；
/// - 无注册消费者时自动销毁 MachPort 与 RunLoopSource，保持空闲零开销；
/// - 遇到系统 `tapDisabledByTimeout` 时毫秒级自动重连恢复。
public final class EventTapBus: @unchecked Sendable {
    public static let shared = EventTapBus(enableSystemTap: true)

    private let lock = NSLock()
    private let enableSystemTap: Bool
    private var entries: [EventTapEntry] = []
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var installedMask: CGEventMask = 0

    private var dispatchedCount: UInt64 = 0
    private var suppressedCount: UInt64 = 0
    private var replacedCount: UInt64 = 0
    private var timeoutRecoveryCount: UInt64 = 0

    public init(enableSystemTap: Bool = true) {
        self.enableSystemTap = enableSystemTap
    }

    deinit {
        lock.lock()
        teardownTapLocked()
        lock.unlock()
    }

    /// 注册或替换同 ID 处理器，并按需创建或更新底层 CGEventTap
    @discardableResult
    public func register(_ entry: EventTapEntry) -> UUID {
        lock.lock()
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        reconcileTapLocked()
        lock.unlock()
        return entry.id
    }

    /// 注销指定处理器；若已无任何消费者，立即释放系统事件 Tap
    public func unregister(_ id: UUID) {
        lock.lock()
        entries.removeAll { $0.id == id }
        reconcileTapLocked()
        lock.unlock()
    }

    /// 清空全部已注册处理器并释放底层事件 Tap
    public func unregisterAll() {
        lock.lock()
        entries.removeAll()
        teardownTapLocked()
        lock.unlock()
    }

    /// 当用户刚刚授予辅助功能权限后，主动刷新底层 Tap 挂载状态
    public func refreshTapBinding() {
        lock.lock()
        reconcileTapLocked()
        lock.unlock()
    }

    public var registeredCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public var isTapInstalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let port = machPort else { return false }
        return CGEvent.tapIsEnabled(tap: port)
    }

    public func statisticsSnapshot() -> EventTapStatistics {
        lock.lock()
        defer { lock.unlock() }
        let active = machPort.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        return EventTapStatistics(
            registeredHandlers: entries.count,
            isTapActive: active,
            dispatchedEvents: dispatchedCount,
            suppressedEvents: suppressedCount,
            replacedEvents: replacedCount,
            timeoutRecoveries: timeoutRecoveryCount
        )
    }

    /// 纯函数确定性调度核心：按优先级降序执行掩码匹配的处理器，支持 `.suppress` 短路与 `.replace` 传递
    public static func dispatch(
        entries: [EventTapEntry],
        eventType: CGEventType,
        context: EventTapContext
    ) -> EventTapDisposition {
        guard !entries.isEmpty else { return .passThrough }

        let ordered = entries.enumerated().sorted { lhs, rhs in
            if lhs.element.priority != rhs.element.priority {
                return lhs.element.priority > rhs.element.priority
            }
            return lhs.offset < rhs.offset
        }

        var currentContext = context
        var latestReplacement: CGEvent?

        for (_, entry) in ordered {
            guard entry.matches(eventType) else { continue }
            let disposition = entry.handler(currentContext)
            switch disposition {
            case .passThrough:
                continue
            case .suppress:
                return .suppress
            case .replace(let updatedEvent):
                latestReplacement = updatedEvent
                currentContext.cgEvent = updatedEvent
            }
        }

        if let replacement = latestReplacement {
            return .replace(replacement)
        }
        return .passThrough
    }

    // MARK: - 私有 MachPort 生命周期管理

    private func reconcileTapLocked() {
        let unionMask = entries.reduce(0 as CGEventMask) { $0 | $1.eventMask }
        guard !entries.isEmpty, unionMask != 0, enableSystemTap else {
            teardownTapLocked()
            return
        }

        guard AXIsProcessTrusted() else {
            teardownTapLocked()
            return
        }

        if let existingPort = machPort, installedMask == unionMask {
            if !CGEvent.tapIsEnabled(tap: existingPort) {
                CGEvent.tapEnable(tap: existingPort, enable: true)
            }
            return
        }

        teardownTapLocked()

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let bus = Unmanaged<EventTapBus>.fromOpaque(userInfo).takeUnretainedValue()
            return bus.handleRawCallback(type: type, event: event)
        }

        guard let createdPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: unionMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdPort, 0) else {
            CFMachPortInvalidate(createdPort)
            return
        }

        machPort = createdPort
        runLoopSource = source
        installedMask = unionMask
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: createdPort, enable: true)
    }

    private func teardownTapLocked() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port = machPort {
            CFMachPortInvalidate(port)
        }
        runLoopSource = nil
        machPort = nil
        installedMask = 0
    }

    private func handleRawCallback(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            if let port = machPort, !entries.isEmpty {
                CGEvent.tapEnable(tap: port, enable: true)
                timeoutRecoveryCount &+= 1
            }
            lock.unlock()
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let snapshot = entries
        dispatchedCount &+= 1
        lock.unlock()

        guard !snapshot.isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        let context = EventTapContext(eventType: type, cgEvent: event)
        let decision = Self.dispatch(entries: snapshot, eventType: type, context: context)

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .suppress:
            lock.lock()
            suppressedCount &+= 1
            lock.unlock()
            return nil
        case .replace(let replacement):
            lock.lock()
            replacedCount &+= 1
            lock.unlock()
            return Unmanaged.passUnretained(replacement)
        }
    }
}
