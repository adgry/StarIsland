import AppKit
import XCTest
@testable import Sapphire

final class StarIslandPremiumManagersTests: XCTestCase {
    func testCleanURLStripsTrackingParamsAndPreservesFunctionalFromParam() {
        let raw = "https://www.bilibili.com/video/BV1xx411c7mD?spm_id_from=333.1007&vd_source=abc123&utm_source=copy_web&from=search"
        let cleaned = CleanURLManager.cleanedURL(raw, extraParams: [])
        XCTAssertEqual(cleaned, "https://www.bilibili.com/video/BV1xx411c7mD?from=search")
    }

    func testStorageSpaceMapSnapshotComputesSlicesAndFreeBytes() {
        var cachesEntry = StorageEntry(url: URL(fileURLWithPath: "/tmp/Caches"), size: 4_000_000_000, isDirectory: true)
        cachesEntry.category = .caches
        var downloadsEntry = StorageEntry(url: URL(fileURLWithPath: "/tmp/Downloads"), size: 6_000_000_000, isDirectory: true)
        downloadsEntry.category = .downloads

        let snapshot = StorageSpaceMapSnapshot.make(
            from: [cachesEntry, downloadsEntry],
            maximumItems: 8,
            used: 20_000_000_000,
            total: 100_000_000_000,
            deepScanEnabled: false,
            entriesSortedBySize: false
        )

        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertEqual(snapshot.items.first?.name, "Downloads")
        XCTAssertEqual(snapshot.accountedBytes, 10_000_000_000)
        XCTAssertEqual(snapshot.freeBytes, 80_000_000_000)
        XCTAssertEqual(snapshot.usedRatio, 0.2, accuracy: 0.001)
    }

    func testDebounceAndExtraClickFilterLogic() {
        XCTAssertTrue(ExtraClickFilterManager.shouldSuppressClick(deltaSeconds: 0.015, threshold: 0.04))
        XCTAssertFalse(ExtraClickFilterManager.shouldSuppressClick(deltaSeconds: 0.12, threshold: 0.04))

        XCTAssertTrue(KeyboardDebounceManager.shouldSuppressKeyRepeat(deltaSeconds: 0.018, threshold: 0.045))
        XCTAssertFalse(KeyboardDebounceManager.shouldSuppressKeyRepeat(deltaSeconds: 0.095, threshold: 0.045))
    }

    @MainActor
    func testMediaOptimizerCompressesImageWithoutPaywallError() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("sample.png")
        let size = NSSize(width: 640, height: 480)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemOrange.setFill()
            rect.insetBy(dx: 80, dy: 80).fill()
            return true
        }
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let pngData = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try pngData.write(to: imageURL)

        XCTAssertEqual(MediaOptimizer.kind(for: imageURL), .image)
        XCTAssertTrue(MediaOptimizer.canOCR(imageURL))

        let outcome = await MediaOptimizerManager.shared.optimizeFile(imageURL)
        switch outcome {
        case .success(let result):
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
            XCTAssertGreaterThan(result.optimizedBytes, 0)
        case .failure(let error):
            XCTFail("Expected image optimization to succeed, got error: \(error)")
        }
    }

    func testNoStubUnavailableStringsRemainInStubsDirectory() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let stubsDir = repoRoot.appendingPathComponent("Sapphire/Stubs", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: stubsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)

        let forbidden = "当前构建版本" + "未包含"
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                content.contains(forbidden),
                "Stub placeholder found in \(file.lastPathComponent)"
            )
        }
    }
}
