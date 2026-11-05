import CoreGraphics
import Foundation
import IslandCore
import SystemEnhanceKit
import XCTest

final class SystemEnhanceKitTests: XCTestCase {
    // MARK: - 1. EventTapBus 优先级调度、短路拦截与事件掩码过滤

    func testEventTapBusPriorityOrderAndSuppressShortCircuit() {
        var executionOrder: [String] = []
        let keyDownMask = EventTapEntry.mask(for: [.keyDown])

        let lowEntry = EventTapEntry(name: "low", priority: 10, eventMask: keyDownMask) { _ in
            executionOrder.append("low")
            return .passThrough
        }
        let highEntry = EventTapEntry(name: "high", priority: 100, eventMask: keyDownMask) { _ in
            executionOrder.append("high")
            return .passThrough
        }
        let midPassEntry = EventTapEntry(name: "midPass", priority: 50, eventMask: keyDownMask) { _ in
            executionOrder.append("midPass")
            return .passThrough
        }

        let context = EventTapContext(eventType: .keyDown, keyCode: 12, flags: .maskCommand)
        let passResult = EventTapBus.dispatch(
            entries: [lowEntry, highEntry, midPassEntry],
            eventType: .keyDown,
            context: context
        )
        XCTAssertEqual(passResult, .passThrough)
        XCTAssertEqual(executionOrder, ["high", "midPass", "low"])

        // 当高/中优先级返回 .suppress 时立即短路，低优先级不再执行
        executionOrder.removeAll()
        let midSuppressEntry = EventTapEntry(name: "midSuppress", priority: 50, eventMask: keyDownMask) { _ in
            executionOrder.append("midSuppress")
            return .suppress
        }
        let suppressResult = EventTapBus.dispatch(
            entries: [lowEntry, highEntry, midSuppressEntry],
            eventType: .keyDown,
            context: context
        )
        XCTAssertEqual(suppressResult, .suppress)
        XCTAssertEqual(executionOrder, ["high", "midSuppress"])
    }

    func testEventTapBusSkipsMismatchedEventMaskAndLifecycle() {
        var invokedNames: [String] = []

        let mouseOnlyEntry = EventTapEntry(
            name: "mouseOnly",
            priority: 200,
            eventMask: EventTapEntry.mask(for: [.leftMouseDown])
        ) { _ in
            invokedNames.append("mouseOnly")
            return .suppress
        }
        let keyEntry = EventTapEntry(
            name: "keyHandler",
            priority: 20,
            eventMask: EventTapEntry.mask(for: [.keyDown])
        ) { _ in
            invokedNames.append("keyHandler")
            return .passThrough
        }

        let ctx = EventTapContext(eventType: .keyDown, keyCode: 0)
        let disposition = EventTapBus.dispatch(
            entries: [mouseOnlyEntry, keyEntry],
            eventType: .keyDown,
            context: ctx
        )

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(invokedNames, ["keyHandler"])

        let bus = EventTapBus(enableSystemTap: false)
        let id1 = bus.register(mouseOnlyEntry)
        let id2 = bus.register(keyEntry)
        XCTAssertEqual(bus.registeredCount, 2)

        bus.unregister(id1)
        XCTAssertEqual(bus.registeredCount, 1)

        bus.unregister(id2)
        XCTAssertEqual(bus.registeredCount, 0)
        XCTAssertFalse(bus.isTapInstalled)
    }

    // MARK: - 2. WindowSnapGeometry 10 种分屏矩形计算与边缘命中判定

    func testWindowSnapGeometryAllTenZonesTargetFrames() {
        let visible = CGRect(x: 0, y: 50, width: 1500, height: 900)

        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .leftHalf, in: visible),
            CGRect(x: 0, y: 50, width: 750, height: 900)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .rightHalf, in: visible),
            CGRect(x: 750, y: 50, width: 750, height: 900)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .topMaximize, in: visible),
            CGRect(x: 0, y: 50, width: 1500, height: 900)
        )

        // 四角四分屏（AppKit 坐标系：minY 在底部，maxY 在顶部）
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .topLeftQuarter, in: visible),
            CGRect(x: 0, y: 500, width: 750, height: 450)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .topRightQuarter, in: visible),
            CGRect(x: 750, y: 500, width: 750, height: 450)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .bottomLeftQuarter, in: visible),
            CGRect(x: 0, y: 50, width: 750, height: 450)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .bottomRightQuarter, in: visible),
            CGRect(x: 750, y: 50, width: 750, height: 450)
        )

        // 左中右三分屏
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .leftThird, in: visible),
            CGRect(x: 0, y: 50, width: 500, height: 900)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .centerThird, in: visible),
            CGRect(x: 500, y: 50, width: 500, height: 900)
        )
        XCTAssertEqual(
            WindowSnapGeometry.targetFrame(for: .rightThird, in: visible),
            CGRect(x: 1000, y: 50, width: 500, height: 900)
        )
    }

    func testWindowSnapGeometryHoveredZoneDetection() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let threshold: CGFloat = 20

        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 6, y: 450), in: screen, edgeThreshold: threshold),
            .leftHalf
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 1440, y: 450), in: screen, edgeThreshold: threshold),
            .rightHalf
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 720, y: 892), in: screen, edgeThreshold: threshold),
            .topMaximize
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 8, y: 894), in: screen, edgeThreshold: threshold),
            .topLeftQuarter
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 1435, y: 895), in: screen, edgeThreshold: threshold),
            .topRightQuarter
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 8, y: 6), in: screen, edgeThreshold: threshold),
            .bottomLeftQuarter
        )
        XCTAssertEqual(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 1434, y: 5), in: screen, edgeThreshold: threshold),
            .bottomRightQuarter
        )
        XCTAssertNil(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: 720, y: 450), in: screen, edgeThreshold: threshold)
        )
        XCTAssertNil(
            WindowSnapGeometry.hoveredZone(cursor: CGPoint(x: -10, y: 450), in: screen, edgeThreshold: threshold)
        )
    }

    // MARK: - 3. ClickDebounceFilter 微动防连击时间窗过滤

    func testClickDebounceFilterSuppressesBounceWithinThreshold() {
        var filter = ClickDebounceFilter(thresholdMs: 40)
        let baseNs: UInt64 = 1_000_000_000 // 1.000s

        // 首次按下左键正常放行
        XCTAssertFalse(filter.shouldSuppressPress(button: 0, timestampNs: baseNs))
        // 18ms 内再次按下左键判定为微动连击抖动并拦截
        XCTAssertTrue(filter.shouldSuppressPress(button: 0, timestampNs: baseNs + 18_000_000))
        // 25ms 时按下右键（不同按键互不干扰）正常放行
        XCTAssertFalse(filter.shouldSuppressPress(button: 1, timestampNs: baseNs + 25_000_000))
        // 55ms（超过 40ms 阈值）再次按下左键正常放行
        XCTAssertFalse(filter.shouldSuppressPress(button: 0, timestampNs: baseNs + 55_000_000))
    }

    // MARK: - 4. HoldCommandQStateMachine 长按 ⌘Q 状态机

    func testHoldCommandQShortPressAndFullHoldLifecycle() {
        var machine = HoldCommandQStateMachine(
            holdDuration: 0.8,
            whitelistedBundleIDs: ["com.apple.Terminal"]
        )

        // 短按 ⌘Q：首次按下拦截并提示进度 0
        let initialDecision = machine.handleKeyDown(bundleID: "com.apple.Safari", timestamp: 100.0)
        XCTAssertEqual(initialDecision, .interceptHolding(progress: 0.0))

        // 按住 0.4s（未满 0.8s）仍拦截并返回约 0.5 进度
        let midDecision = machine.evaluateHoldProgress(at: 100.4)
        if case .interceptHolding(let progress) = midDecision {
            XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        } else {
            XCTFail("未满设定按住时长时应继续拦截")
        }

        // 中途松开按键，取消本次退出计时
        XCTAssertEqual(machine.handleKeyRelease(), .cancelled)

        // 重新按下并按住满 0.8s，放行退出
        XCTAssertEqual(machine.handleKeyDown(bundleID: "com.apple.Safari", timestamp: 105.0), .interceptHolding(progress: 0.0))
        XCTAssertEqual(machine.evaluateHoldProgress(at: 105.85), .allowQuit)
        _ = machine.handleKeyRelease()

        // 白名单应用直接放行
        XCTAssertEqual(machine.handleKeyDown(bundleID: "com.apple.Terminal", timestamp: 110.0), .allowQuit)
    }

    // MARK: - 5. EmojiSuggestEngine 中英文关键词联想

    func testEmojiSuggestEngineMatchesChineseAndEnglishKeywords() {
        let rocketCN = EmojiSuggestEngine.match(token: ":火箭")
        XCTAssertFalse(rocketCN.isEmpty)
        XCTAssertEqual(rocketCN.first?.emoji, "🚀")

        let rocketEN = EmojiSuggestEngine.match(token: ":rocket")
        XCTAssertFalse(rocketEN.isEmpty)
        XCTAssertEqual(rocketEN.first?.emoji, "🚀")

        let laughCandidates = EmojiSuggestEngine.match(token: ":大笑").map(\.emoji)
        XCTAssertFalse(laughCandidates.isEmpty)
        XCTAssertTrue(laughCandidates.contains("😂") || laughCandidates.contains("😄"))
        XCTAssertTrue(laughCandidates.contains("😂") && laughCandidates.contains("😄"))

        XCTAssertTrue(EmojiSuggestEngine.match(token: ":").isEmpty)
        XCTAssertTrue(EmojiSuggestEngine.match(token: ":完全不存在的词条999").isEmpty)
    }

    // MARK: - 6. AppLockService 锁定拦截、解锁有效期与超时自动恢复锁定

    @MainActor
    func testAppLockServiceActivationBlockAndRelockAfterTimeout() {
        let service = AppLockService(relockInterval: 60)
        service.lockedBundleIDs = ["com.tencent.xinWeChat"]

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // 未在锁定列表中的应用不拦截
        XCTAssertFalse(service.shouldBlockActivation(bundleID: "com.apple.finder", now: t0))

        // 受保护应用未解锁时拦截激活
        XCTAssertTrue(service.shouldBlockActivation(bundleID: "com.tencent.xinWeChat", now: t0))

        // 记录生物识别解锁成功后，在 60s 有效期内放行
        service.recordUnlock(bundleID: "com.tencent.xinWeChat", now: t0)
        XCTAssertFalse(service.shouldBlockActivation(bundleID: "com.tencent.xinWeChat", now: t0.addingTimeInterval(30)))

        // 超过 relockInterval（61s）自动恢复锁定
        XCTAssertTrue(service.shouldBlockActivation(bundleID: "com.tencent.xinWeChat", now: t0.addingTimeInterval(61)))

        // 再次解锁后调用 lockImmediately 立即上锁
        let t1 = t0.addingTimeInterval(100)
        service.recordUnlock(bundleID: "com.tencent.xinWeChat", now: t1)
        XCTAssertFalse(service.shouldBlockActivation(bundleID: "com.tencent.xinWeChat", now: t1.addingTimeInterval(5)))
        service.lockImmediately(bundleID: "com.tencent.xinWeChat")
        XCTAssertTrue(service.shouldBlockActivation(bundleID: "com.tencent.xinWeChat", now: t1.addingTimeInterval(6)))
    }

    // MARK: - 7. Finder 剪切状态机、机械键盘消抖与协调器零开销生命周期

    @MainActor
    func testFinderCutPasteAndKeyboardDebounceAndCoordinatorLifecycle() {
        var tracker = FinderCutPasteTracker()
        XCTAssertEqual(tracker.handleFinderCommandKey(keyCode: 7, flags: .maskCommand), .synthesizeCopyAndArmCut)
        XCTAssertTrue(tracker.isCutArmed)
        XCTAssertEqual(tracker.handleFinderCommandKey(keyCode: 9, flags: .maskCommand), .convertPasteToMove)
        XCTAssertFalse(tracker.isCutArmed)
        // 二次粘贴回退为普通粘贴，不重复移动
        XCTAssertEqual(tracker.handleFinderCommandKey(keyCode: 9, flags: .maskCommand), .none)

        var keyFilter = KeyboardDebounceFilter(thresholdMs: 25)
        let baseNs: UInt64 = 2_000_000_000
        XCTAssertFalse(keyFilter.shouldSuppressKeyDown(keyCode: 36, isAutoRepeat: false, timestampNs: baseNs))
        XCTAssertTrue(keyFilter.shouldSuppressKeyDown(keyCode: 36, isAutoRepeat: false, timestampNs: baseNs + 10_000_000))
        XCTAssertFalse(keyFilter.shouldSuppressKeyDown(keyCode: 36, isAutoRepeat: true, timestampNs: baseNs + 15_000_000))
        XCTAssertFalse(keyFilter.shouldSuppressKeyDown(keyCode: 36, isAutoRepeat: false, timestampNs: baseNs + 35_000_000))

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("sys-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let journal = MutationJournal(fileURL: tempDir.appendingPathComponent("journal.json"))
        let bus = EventTapBus(enableSystemTap: false)
        let coordinator = SystemEnhanceCoordinator(
            settingsStore: store,
            stateMachine: IslandStateMachine(),
            mutationJournal: journal,
            eventTapBus: bus
        )

        coordinator.start()
        XCTAssertGreaterThan(bus.registeredCount, 0)
        coordinator.stop()
        XCTAssertEqual(bus.registeredCount, 0)
    }
}
