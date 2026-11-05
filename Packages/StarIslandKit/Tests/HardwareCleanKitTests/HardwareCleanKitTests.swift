import Foundation
import XCTest
@testable import HardwareCleanKit
import IslandCore

final class HardwareCleanKitTests: XCTestCase {

    // MARK: - 1. CodesignValidator 父级 .app 归属校验

    func testCodesignValidatorMatchesSameParentAppAndRejectsOthers() {
        let helperURL = URL(
            fileURLWithPath: "/Applications/StarIsland.app/Contents/MacOS/com.adgry.starisland.helper"
        )
        let matchingClient = URL(fileURLWithPath: "/Applications/StarIsland.app")
        let matchingClientTrailingSlash = URL(fileURLWithPath: "/Applications/StarIsland.app/")
        let otherApp = URL(fileURLWithPath: "/Users/tmp/Other.app")
        let copiedElsewhere = URL(fileURLWithPath: "/Users/tmp/StarIsland.app")
        let nestedFakeApp = URL(
            fileURLWithPath: "/Applications/StarIsland.app/Contents/Resources/Fake.app"
        )

        XCTAssertTrue(
            CodesignValidator.isParentAppMatch(
                helperExecutableURL: helperURL,
                clientBundleURL: matchingClient
            )
        )
        XCTAssertTrue(
            CodesignValidator.isParentAppMatch(
                helperExecutableURL: helperURL,
                clientBundleURL: matchingClientTrailingSlash
            )
        )
        XCTAssertFalse(
            CodesignValidator.isParentAppMatch(
                helperExecutableURL: helperURL,
                clientBundleURL: otherApp
            )
        )
        XCTAssertFalse(
            CodesignValidator.isParentAppMatch(
                helperExecutableURL: helperURL,
                clientBundleURL: copiedElsewhere
            )
        )
        XCTAssertFalse(
            CodesignValidator.isParentAppMatch(
                helperExecutableURL: helperURL,
                clientBundleURL: nestedFakeApp
            )
        )
    }

    // MARK: - 2. BatteryChargePolicy 充电上限、巡航与高温保护策略

    func testBatteryChargePolicyPrioritizesOverheatRegardlessOfBatteryLevel() {
        let actionWhileLowBattery = BatteryChargePolicy.decideAction(
            level: 32,
            isCharging: true,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 43.5,
            maxTempC: 42.0
        )
        XCTAssertEqual(actionWhileLowBattery, .inhibitCharging(reason: .overheat))

        let actionAtExactThreshold = BatteryChargePolicy.decideAction(
            level: 50,
            isCharging: false,
            limit: 100,
            sailingDrop: 5,
            temperatureC: 42.0,
            maxTempC: 42.0
        )
        XCTAssertEqual(actionAtExactThreshold, .inhibitCharging(reason: .overheat))
    }

    func testBatteryChargePolicyInhibitsAtOrAboveLimit() {
        let atLimit = BatteryChargePolicy.decideAction(
            level: 80,
            isCharging: true,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 34.0,
            maxTempC: 42.0
        )
        XCTAssertEqual(atLimit, .inhibitCharging(reason: .reachedLimit))

        let aboveLimit = BatteryChargePolicy.decideAction(
            level: 88,
            isCharging: false,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 34.0,
            maxTempC: 42.0
        )
        XCTAssertEqual(aboveLimit, .inhibitCharging(reason: .reachedLimit))
    }

    func testBatteryChargePolicyMaintainsInhibitInSailingBandAndAllowsBelowDrop() {
        // 处于巡航回落区间（上限 80%，回落 5%，当前 77% 且当前已抑制未在充电） -> 保持抑制
        let sailingMaintain = BatteryChargePolicy.decideAction(
            level: 77,
            isCharging: false,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 33.5,
            maxTempC: 42.0
        )
        XCTAssertEqual(sailingMaintain, .maintainInhibit)

        // 正在充电爬升至 77%（尚未充到 80%） -> 继续允许充电
        let climbingAllow = BatteryChargePolicy.decideAction(
            level: 77,
            isCharging: true,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 33.5,
            maxTempC: 42.0
        )
        XCTAssertEqual(climbingAllow, .allowCharging)

        // 电量回落至 <= 75%（limit - sailingDrop） -> 恢复允许充电
        let atDropThreshold = BatteryChargePolicy.decideAction(
            level: 75,
            isCharging: false,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 33.5,
            maxTempC: 42.0
        )
        XCTAssertEqual(atDropThreshold, .allowCharging)

        let belowDropThreshold = BatteryChargePolicy.decideAction(
            level: 60,
            isCharging: false,
            limit: 80,
            sailingDrop: 5,
            temperatureC: 33.5,
            maxTempC: 42.0
        )
        XCTAssertEqual(belowDropThreshold, .allowCharging)
    }

    // MARK: - 3. FanCurveProfile 温控曲线线性插值与边界钳制

    func testFanCurveProfileTargetRPMInterpolationAndClamping() {
        let profile = FanCurveProfile(points: [
            .init(temperatureC: 40.0, speedRatio: 0.0),
            .init(temperatureC: 60.0, speedRatio: 0.5),
            .init(temperatureC: 80.0, speedRatio: 1.0),
        ])

        let minRPM = 1200
        let maxRPM = 5200

        // 低温段钳制在最低转速
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 28.0, minRPM: minRPM, maxRPM: maxRPM),
            1200
        )
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 40.0, minRPM: minRPM, maxRPM: maxRPM),
            1200
        )

        // 中温段线性插值：50℃ -> 25% -> 2200 RPM；70℃ -> 75% -> 4200 RPM
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 50.0, minRPM: minRPM, maxRPM: maxRPM),
            2200
        )
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 70.0, minRPM: minRPM, maxRPM: maxRPM),
            4200
        )

        // 高温满速段钳制在最高转速
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 80.0, minRPM: minRPM, maxRPM: maxRPM),
            5200
        )
        XCTAssertEqual(
            profile.targetRPM(forTemperatureC: 96.0, minRPM: minRPM, maxRPM: maxRPM),
            5200
        )
    }

    // MARK: - 4. AppCleanerService 精准扫描残留且绝不误伤相似前缀无辜应用

    func testAppCleanerFindsTargetResiduesWithoutFalsePositivesOnSimilarPrefixes() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarIslandAppCleanerTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let appSupport = tempRoot.appendingPathComponent("Application Support", isDirectory: true)
        let caches = tempRoot.appendingPathComponent("Caches", isDirectory: true)
        let preferences = tempRoot.appendingPathComponent("Preferences", isDirectory: true)

        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)

        // 目标应用残留（应当命中）
        let targetSupportDir = appSupport.appendingPathComponent("DemoApp", isDirectory: true)
        let targetCacheDir = caches.appendingPathComponent("com.example.demoapp", isDirectory: true)
        let targetPlist = preferences.appendingPathComponent("com.example.demoapp.plist")

        try FileManager.default.createDirectory(at: targetSupportDir, withIntermediateDirectories: true)
        try Data("support-data".utf8).write(to: targetSupportDir.appendingPathComponent("state.json"))
        try FileManager.default.createDirectory(at: targetCacheDir, withIntermediateDirectories: true)
        try Data("cache-bytes".utf8).write(to: targetCacheDir.appendingPathComponent("db.sqlite"))
        try Data("plist-bytes".utf8).write(to: targetPlist)

        // 相似前缀的无辜应用与无关文件（绝不能误伤！）
        let innocentPrefixSupport = appSupport.appendingPathComponent("DemoAppHelperPro", isDirectory: true)
        let innocentOtherSupport = appSupport.appendingPathComponent("OtherApp", isDirectory: true)
        let innocentPrefixCache = caches.appendingPathComponent("com.example.demoapphelperpro", isDirectory: true)
        let innocentPrefixPlist = preferences.appendingPathComponent("com.example.demoapphelperpro.plist")
        let innocentOtherPlist = preferences.appendingPathComponent("com.other.utility.plist")

        try FileManager.default.createDirectory(at: innocentPrefixSupport, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: innocentPrefixSupport.appendingPathComponent("important.dat"))
        try FileManager.default.createDirectory(at: innocentOtherSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: innocentPrefixCache, withIntermediateDirectories: true)
        try Data("keep-plist".utf8).write(to: innocentPrefixPlist)
        try Data("keep-other".utf8).write(to: innocentOtherPlist)

        let residues = AppCleanerService.findResidueURLs(
            bundleID: "com.example.demoapp",
            appName: "DemoApp",
            searchRoots: [appSupport, caches, preferences]
        )

        let matchedPaths = Set(residues.map { $0.url.standardizedFileURL.path })
        let expectedPaths: Set<String> = [
            targetSupportDir.standardizedFileURL.path,
            targetCacheDir.standardizedFileURL.path,
            targetPlist.standardizedFileURL.path,
        ]

        XCTAssertEqual(matchedPaths, expectedPaths)
        XCTAssertFalse(matchedPaths.contains(innocentPrefixSupport.standardizedFileURL.path))
        XCTAssertFalse(matchedPaths.contains(innocentOtherSupport.standardizedFileURL.path))
        XCTAssertFalse(matchedPaths.contains(innocentPrefixCache.standardizedFileURL.path))
        XCTAssertFalse(matchedPaths.contains(innocentPrefixPlist.standardizedFileURL.path))
        XCTAssertTrue(residues.allSatisfy { $0.sizeBytes > 0 })
    }

    // MARK: - 5. HelperCoordinator 启动对账期间隐藏误报与重装时序保证

    @MainActor
    func testHelperCoordinatorHidesVisibleIssueWhileReconcilingAndDisconnectsBeforeReinstall() async throws {
        var recordedEvents: [String] = []
        var mockPingResult = false

        let coordinator = HelperCoordinator(
            initialStatus: .enabled,
            initialReconciling: true,
            statusProvider: { .enabled },
            registerHandler: {
                recordedEvents.append("register")
            },
            unregisterHandler: {
                recordedEvents.append("unregister")
            },
            disconnectHandler: {
                recordedEvents.append("disconnectXPC")
            },
            pingHandler: {
                recordedEvents.append("ping")
                return mockPingResult
            },
            sleepMilliseconds: { ms in
                recordedEvents.append("sleep:\(ms)")
            }
        )

        // 初始启动对账期间（isReconciling == true），即使 status == .enabled 且未连通，visibleIssue 必须为 nil
        XCTAssertEqual(coordinator.status, .enabled)
        XCTAssertFalse(coordinator.isConnected)
        XCTAssertTrue(coordinator.isReconciling)
        XCTAssertNil(coordinator.visibleIssue)

        // 对账结束但仍未连通时，才展示可读中文故障提示
        await coordinator.reconcileConnection()
        XCTAssertFalse(coordinator.isReconciling)
        XCTAssertFalse(coordinator.isConnected)
        XCTAssertNotNil(coordinator.visibleIssue)

        // 执行重装修复：必先断开 XPC -> 等 400ms -> unregister -> 等 1200ms -> register -> 重新握手连通
        recordedEvents.removeAll()
        mockPingResult = true
        await coordinator.reinstallHelper()

        XCTAssertEqual(
            recordedEvents,
            ["disconnectXPC", "sleep:400", "unregister", "sleep:1200", "register", "ping"]
        )
        XCTAssertTrue(coordinator.isConnected)
        XCTAssertFalse(coordinator.isReconciling)
        XCTAssertNil(coordinator.visibleIssue)
    }

    // MARK: - 6. BatteryFanManager 与 MutationJournal 崩溃自愈与退出还原（Review Focus #4）

    @MainActor
    func testBatteryFanManagerMutationJournalCrashRecoveryAndTerminationRestore() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarIslandHWJournalTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let journal = MutationJournal(fileURL: tempDir.appendingPathComponent("journal.json"))
        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let stateMachine = IslandStateMachine(observeSystemLockNotifications: false)
        let mockHelper = MockPrivilegedHelper()

        // 模拟上次异常退出残留的充电抑制与手动风扇记录
        journal.record(
            MutationRecord(kind: .batteryChargeInhibit, previousValue: "allow:100", appliedValue: "inhibit:80")
        )
        journal.record(
            MutationRecord(kind: .fanManualControl, previousValue: "auto", appliedValue: "manual:4200")
        )

        let manager = BatteryFanManager(
            helper: mockHelper,
            settingsStore: settingsStore,
            journal: journal,
            stateMachine: stateMachine
        )

        await manager.recoverPendingMutationsIfNeeded()

        XCTAssertEqual(mockHelper.lastChargeInhibitCall?.inhibit, false)
        XCTAssertEqual(mockHelper.lastFanControlCall?.manual, false)
        XCTAssertTrue(journal.pendingRecords().isEmpty)

        // 开启高温保护与风扇全速模式，模拟触发硬件写入并记录日志
        settingsStore.settings.enableBatteryChargeLimit = true
        settingsStore.settings.batteryChargeLimit = 80
        settingsStore.settings.enableThermalChargeProtection = true
        settingsStore.settings.maxChargeTemperatureCelsius = 42.0
        settingsStore.settings.fanControlMode = "turbo"

        mockHelper.mockSnapshot = BatteryHardwareSnapshot(
            percentage: 65,
            isCharging: true,
            isPluggedIn: true,
            temperatureCelsius: 44.2,
            cycleCount: 120,
            currentFanRPM: 2000,
            minFanRPM: 1200,
            maxFanRPM: 5400
        )

        await manager.evaluateAndApply()
        XCTAssertTrue(manager.isChargeInhibited)
        XCTAssertTrue(manager.isThermalWarningActive)
        XCTAssertEqual(mockHelper.lastFanControlCall?.manual, true)
        XCTAssertEqual(mockHelper.lastFanControlCall?.targetRPM, 5400)
        XCTAssertFalse(journal.pendingRecords().isEmpty)

        // 应用正常退出时按 MutationJournal 恢复系统自动充电与自动风扇
        await manager.restoreSystemDefaultsOnTermination()
        XCTAssertEqual(mockHelper.lastChargeInhibitCall?.inhibit, false)
        XCTAssertEqual(mockHelper.lastFanControlCall?.manual, false)
        XCTAssertTrue(journal.pendingRecords().isEmpty)
    }

    // MARK: - 7. 存储空间分析与 DMG hdiutil Plist 挂载点解析

    func testStorageSnapshotAndDMGMountPlistParsing() throws {
        let storage = StorageAnalyzerService.currentSnapshot()
        XCTAssertGreaterThan(storage.totalDiskBytes, 0)
        XCTAssertGreaterThanOrEqual(storage.availableDiskBytes, 0)
        XCTAssertGreaterThan(storage.physicalMemoryBytes, 0)

        let samplePlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>system-entities</key>
            <array>
                <dict>
                    <key>dev-entry</key>
                    <string>/dev/disk6s1</string>
                </dict>
                <dict>
                    <key>dev-entry</key>
                    <string>/dev/disk6s2</string>
                    <key>mount-point</key>
                    <string>/Volumes/DemoInstaller</string>
                </dict>
            </array>
        </dict>
        </plist>
        """
        let mounts = DMGAutoInstaller.parseMountPoints(fromHdiutilPlistData: Data(samplePlist.utf8))
        XCTAssertEqual(mounts.map(\.path), ["/Volumes/DemoInstaller"])
    }
}

// MARK: - 测试桩

private final class MockPrivilegedHelper: PrivilegedHelperProtocol, @unchecked Sendable {
    var mockSnapshot = BatteryHardwareSnapshot()
    var lastChargeInhibitCall: (inhibit: Bool, limit: Int)?
    var lastFanControlCall: (manual: Bool, targetRPM: Int)?

    func ping() async -> Bool { true }

    func readHardwareSnapshot() async -> BatteryHardwareSnapshot? {
        mockSnapshot
    }

    func setChargeInhibit(_ inhibit: Bool, chargeLimit: Int) async -> Bool {
        lastChargeInhibitCall = (inhibit, chargeLimit)
        return true
    }

    func setFanControl(manual: Bool, targetRPM: Int) async -> Bool {
        lastFanControlCall = (manual, targetRPM)
        return true
    }

    func applyManagedBlockedDomains(_ domains: [String]) async -> Bool { true }

    func installStagedUpdate(from stagedAppPath: String, to targetAppPath: String) async throws -> Bool { true }
}
