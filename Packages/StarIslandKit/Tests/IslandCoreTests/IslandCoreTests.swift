import XCTest
@testable import IslandCore

final class IslandCoreTests: XCTestCase {

    func testPhysicalNotchAndExternalScreenGeometry() {
        let notched = IslandGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeTopInset: 38,
            auxiliaryLeftWidth: 640,
            auxiliaryRightWidth: 640,
            scale: 1.0
        )
        XCTAssertTrue(notched.hasPhysicalNotch)
        XCTAssertEqual(notched.compactSize.width, 232, accuracy: 0.5)
        XCTAssertEqual(notched.compactSize.height, 38, accuracy: 0.5)

        let external = IslandGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeTopInset: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil,
            scale: 1.0
        )
        XCTAssertFalse(external.hasPhysicalNotch)
        XCTAssertEqual(external.compactSize.width, 184, accuracy: 0.5)
        XCTAssertEqual(external.compactSize.height, 32, accuracy: 0.5)
        XCTAssertGreaterThan(external.expandedSize.width, external.pillSize.width)
    }

    @MainActor
    func testStateMachinePriorityArbitrationHoverAndLockScreenFiltering() {
        let machine = IslandStateMachine()
        XCTAssertEqual(machine.displayState, .compact)

        let music = IslandActivityItem(
            id: "music-1",
            category: .media,
            title: "夜曲",
            subtitle: "周杰伦",
            iconSymbol: "music.note",
            priority: .ongoing,
            allowsOnLockScreen: true
        )
        machine.submit(music)
        XCTAssertEqual(machine.displayState, .pill)
        XCTAssertEqual(machine.primaryActivity?.id, "music-1")

        let clipboardSecret = IslandActivityItem(
            id: "clip-1",
            category: .clipboard,
            title: "已复制敏感文本",
            subtitle: "剪贴板",
            iconSymbol: "doc.on.clipboard",
            priority: .interactive,
            allowsOnLockScreen: false
        )
        machine.submit(clipboardSecret)
        XCTAssertEqual(machine.primaryActivity?.id, "clip-1")

        // When screen locks, non-lockscreen-safe activities must be filtered from visible primary
        machine.setScreenLocked(true)
        XCTAssertEqual(machine.primaryActivity?.id, "music-1")

        machine.setScreenLocked(false)
        machine.setHovering(true)
        XCTAssertEqual(machine.displayState, .expanded)

        let hud = IslandActivityItem(
            id: "hud-vol",
            category: .systemHUD,
            title: "音量",
            subtitle: "75%",
            iconSymbol: "speaker.wave.3.fill",
            priority: .urgent,
            isAlertHUD: true,
            allowsOnLockScreen: true
        )
        machine.setHovering(false)
        machine.submit(hud)
        XCTAssertEqual(machine.displayState, .alertHUD)

        machine.dismiss(id: "hud-vol")
        machine.dismiss(id: "clip-1")
        XCTAssertEqual(machine.displayState, .pill)
        machine.dismiss(id: "music-1")
        XCTAssertEqual(machine.displayState, .compact)
    }

    func testConsumedEventStoreDeduplicatesPersistsAndExpires() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("consumed.json")
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        let store = ConsumedEventStore(fileURL: fileURL, maxEntries: 3, ttl: 600)
        XCTAssertTrue(store.tryConsume(fingerprint: "otp-3068-a", now: t0))
        XCTAssertFalse(store.tryConsume(fingerprint: "otp-3068-a", now: t0.addingTimeInterval(10)), "duplicate fingerprint must be rejected")

        // Reload from disk across app restarts
        let reloaded = ConsumedEventStore(fileURL: fileURL, maxEntries: 3, ttl: 600)
        XCTAssertTrue(reloaded.hasConsumed(fingerprint: "otp-3068-a", now: t0.addingTimeInterval(30)))
        XCTAssertFalse(reloaded.tryConsume(fingerprint: "otp-3068-a", now: t0.addingTimeInterval(30)))

        // After TTL expires, fingerprint can be consumed again
        XCTAssertTrue(reloaded.tryConsume(fingerprint: "otp-3068-a", now: t0.addingTimeInterval(601)))
    }

    func testMutationJournalPersistsAndClearsCleanly() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("mutations.json")

        let journal = MutationJournal(fileURL: url)
        XCTAssertTrue(journal.pendingRecords().isEmpty)

        let rec = MutationRecord(kind: .batteryChargeLimit, previousValue: "100", appliedValue: "80", recordedAt: Date(timeIntervalSince1970: 500))
        journal.record(rec)

        let secondInstance = MutationJournal(fileURL: url)
        XCTAssertEqual(secondInstance.pendingRecords().count, 1)
        XCTAssertEqual(secondInstance.pendingRecords().first?.appliedValue, "80")

        secondInstance.clear(.batteryChargeLimit)
        XCTAssertTrue(secondInstance.pendingRecords().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testSettingsStoreChineseSearchAndImportExport() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SettingsStore(fileURL: dir.appendingPathComponent("settings.json"))

        let results = store.search("充电上限")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.section == .hardware }))

        store.settings.batteryChargeLimit = 80
        store.settings.enableEightDAudio = true
        let exported = try store.exportJSON()

        let restored = SettingsStore(fileURL: dir.appendingPathComponent("settings2.json"))
        try restored.importJSON(exported)
        XCTAssertEqual(restored.settings.batteryChargeLimit, 80)
        XCTAssertTrue(restored.settings.enableEightDAudio)
    }

    func testLocalNetworkErrorPolicyTreatsOnlyPolicyDeniedAsDenied() {
        // kDNSServiceErr_PolicyDenied = -65570, kDNSServiceErr_NoAuth = -65555
        XCTAssertTrue(LocalNetworkErrorPolicy.isPolicyDenied(dnsErrorCode: -65570))
        XCTAssertFalse(LocalNetworkErrorPolicy.isPolicyDenied(dnsErrorCode: -65555))
        XCTAssertFalse(LocalNetworkErrorPolicy.isPolicyDenied(dnsErrorCode: 0))
    }

    func testSemanticVersionOrderingAndReleaseParsing() throws {
        XCTAssertLessThan(SemanticVersion("1.0.0"), SemanticVersion("1.0.1"))
        XCTAssertLessThan(SemanticVersion("v1.2.9"), SemanticVersion("1.10.0"))
        XCTAssertEqual(SemanticVersion("v3.5.3").buildNumber, 30503)

        let sampleReleaseJSON = """
        {
          "tag_name": "v1.2.0",
          "name": "星岛 v1.2.0",
          "body": "新增全功能更新",
          "html_url": "https://github.com/adgry/StarIsland/releases/tag/v1.2.0",
          "assets": [
            {
              "name": "StarIsland-arm64.zip",
              "browser_download_url": "https://github.com/adgry/StarIsland/releases/download/v1.2.0/StarIsland-arm64.zip",
              "size": 12345678
            }
          ]
        }
        """.data(using: .utf8)!

        let info = try GitHubReleaseParser.parse(data: sampleReleaseJSON)
        XCTAssertEqual(info.version, SemanticVersion("1.2.0"))
        XCTAssertEqual(info.downloadURL?.lastPathComponent, "StarIsland-arm64.zip")
    }
}
