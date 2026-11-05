import AppKit
import ApplicationServices
import Combine
import Foundation
import IslandCore
import SQLite3

public enum ClipboardPayloadKind: String, Codable, CaseIterable, Equatable, Sendable {
    case text
    case url
    case image
    case file

    public var title: String {
        switch self {
        case .text: return "文本"
        case .url: return "链接"
        case .image: return "图片"
        case .file: return "文件"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .text: return "doc.plaintext"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "folder"
        }
    }
}

public struct ClipboardHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: ClipboardPayloadKind
    public var textContent: String
    public var fileURLPaths: [String]
    public var imageThumbnailPNG: Data?
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var wasURLCleaned: Bool
    public var isPinned: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: ClipboardPayloadKind,
        textContent: String,
        fileURLPaths: [String] = [],
        imageThumbnailPNG: Data? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        wasURLCleaned: Bool = false,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.textContent = textContent
        self.fileURLPaths = fileURLPaths
        self.imageThumbnailPNG = imageThumbnailPNG
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.wasURLCleaned = wasURLCleaned
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ClipboardSQLiteStore {
    private var db: OpaquePointer?

    init(fileURL: URL) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            let createSQL = """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                text_content TEXT NOT NULL,
                file_paths_json TEXT NOT NULL,
                thumbnail_blob BLOB,
                app_bundle_id TEXT,
                app_name TEXT,
                was_url_cleaned INTEGER NOT NULL DEFAULT 0,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0
            );
            """
            sqlite3_exec(db, createSQL, nil, nil, nil)
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func loadAll() -> [ClipboardHistoryItem] {
        guard let db else { return [] }
        let sql = """
        SELECT id, kind, text_content, file_paths_json, thumbnail_blob, app_bundle_id, app_name, was_url_cleaned, is_pinned, created_at
        FROM clipboard_items
        ORDER BY sort_order ASC, created_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [ClipboardHistoryItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = Self.readColumnText(stmt, index: 0) ?? ""
            let id = UUID(uuidString: idStr) ?? UUID()
            let kindStr = Self.readColumnText(stmt, index: 1) ?? "text"
            let kind = ClipboardPayloadKind(rawValue: kindStr) ?? .text
            let textContent = Self.readColumnText(stmt, index: 2) ?? ""
            let pathsJSON = Self.readColumnText(stmt, index: 3) ?? "[]"
            let paths = (try? JSONDecoder().decode([String].self, from: Data(pathsJSON.utf8))) ?? []

            var thumbData: Data?
            if let blobPtr = sqlite3_column_blob(stmt, 4) {
                let len = Int(sqlite3_column_bytes(stmt, 4))
                if len > 0 {
                    thumbData = Data(bytes: blobPtr, count: len)
                }
            }

            let bundleID = Self.readColumnText(stmt, index: 5)
            let appName = Self.readColumnText(stmt, index: 6)
            let wasCleaned = sqlite3_column_int(stmt, 7) != 0
            let isPinned = sqlite3_column_int(stmt, 8) != 0
            let timestamp = sqlite3_column_double(stmt, 9)

            results.append(
                ClipboardHistoryItem(
                    id: id,
                    kind: kind,
                    textContent: textContent,
                    fileURLPaths: paths,
                    imageThumbnailPNG: thumbData,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName,
                    wasURLCleaned: wasCleaned,
                    isPinned: isPinned,
                    createdAt: Date(timeIntervalSince1970: timestamp)
                )
            )
        }
        return results
    }

    func replaceAll(_ items: [ClipboardHistoryItem]) {
        guard let db else { return }
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM clipboard_items;", nil, nil, nil)

        let insertSQL = """
        INSERT INTO clipboard_items (
            id, kind, text_content, file_paths_json, thumbnail_blob, app_bundle_id, app_name, was_url_cleaned, is_pinned, created_at, sort_order
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            for (idx, item) in items.enumerated() {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                let pathsData = (try? JSONEncoder().encode(item.fileURLPaths)) ?? Data("[]".utf8)
                let pathsJSON = String(decoding: pathsData, as: UTF8.self)

                sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, item.kind.rawValue, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 3, item.textContent, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 4, pathsJSON, -1, sqliteTransient)

                if let png = item.imageThumbnailPNG, !png.isEmpty {
                    png.withUnsafeBytes { rawBuf in
                        _ = sqlite3_bind_blob(stmt, 5, rawBuf.baseAddress, Int32(png.count), sqliteTransient)
                    }
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                Self.bindOptionalText(stmt, index: 6, value: item.sourceAppBundleID)
                Self.bindOptionalText(stmt, index: 7, value: item.sourceAppName)
                sqlite3_bind_int(stmt, 8, item.wasURLCleaned ? 1 : 0)
                sqlite3_bind_int(stmt, 9, item.isPinned ? 1 : 0)
                sqlite3_bind_double(stmt, 10, item.createdAt.timeIntervalSince1970)
                sqlite3_bind_int(stmt, 11, Int32(idx))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    private static func readColumnText(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cStr)
    }

    private static func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
}

@MainActor
public final class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    public static let concealedTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
        "de.utopia.KeePassXC"
    ]

    @Published public private(set) var items: [ClipboardHistoryItem] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedKindFilter: ClipboardPayloadKind?

    private let store: ClipboardSQLiteStore
    private let settingsStore: SettingsStore
    private let maxItemsOverride: Int?
    private var pollTimer: Timer?
    private var lastObservedChangeCount: Int = NSPasteboard.general.changeCount

    public init(
        databaseURL: URL? = nil,
        settingsStore: SettingsStore? = nil,
        maxItemsOverride: Int? = nil
    ) {
        let resolvedURL = databaseURL ?? StarIslandPaths.appSupportDirectory.appendingPathComponent("clipboard.sqlite3")
        self.store = ClipboardSQLiteStore(fileURL: resolvedURL)
        self.settingsStore = settingsStore ?? .shared
        self.maxItemsOverride = maxItemsOverride
        self.items = store.loadAll()
    }

    public var filteredItems: [ClipboardHistoryItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            if let kindFilter = selectedKindFilter, item.kind != kindFilter {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return item.textContent.lowercased().contains(trimmed)
                || (item.sourceAppName?.lowercased().contains(trimmed) ?? false)
        }
    }

    @discardableResult
    public func ingestPasteboardSnapshot(
        types: [String],
        stringValue: String?,
        fileURLs: [URL] = [],
        imagePNGData: Data? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        now: Date = Date()
    ) -> ClipboardHistoryItem? {
        guard settingsStore.settings.enableClipboardHistory else {
            return nil
        }

        // 密码管理器与临时敏感剪贴板严格跳过不入库
        if types.contains(where: { Self.concealedTypes.contains($0) }) {
            return nil
        }

        var builtItem: ClipboardHistoryItem?

        if !fileURLs.isEmpty {
            let paths = fileURLs.map(\.path)
            let names = fileURLs.map(\.lastPathComponent).joined(separator: "、")
            builtItem = ClipboardHistoryItem(
                kind: .file,
                textContent: names,
                fileURLPaths: paths,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                createdAt: now
            )
        } else if let rawString = stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawString.isEmpty {
            var finalText = rawString
            var wasCleaned = false

            if settingsStore.settings.enableCleanURL {
                let customKeys = Set(settingsStore.settings.customBlockedURLParams)
                if let cleaned = URLCleaner.clean(rawString, customBlockedKeys: customKeys) {
                    finalText = cleaned
                    wasCleaned = true
                }
            }

            let isHTTPURL: Bool = {
                guard !finalText.contains(where: \.isWhitespace),
                      let comps = URLComponents(string: finalText),
                      let scheme = comps.scheme?.lowercased() else { return false }
                return (scheme == "http" || scheme == "https") && comps.host != nil
            }()

            builtItem = ClipboardHistoryItem(
                kind: isHTTPURL ? .url : .text,
                textContent: finalText,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                wasURLCleaned: wasCleaned,
                createdAt: now
            )
        } else if let pngData = imagePNGData, !pngData.isEmpty {
            let thumbnail = Self.makeThumbnailPNG(from: pngData, maxPixel: 240) ?? pngData
            let sizeDesc = Self.describeImageDimensions(from: pngData)
            builtItem = ClipboardHistoryItem(
                kind: .image,
                textContent: sizeDesc,
                imageThumbnailPNG: thumbnail,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                createdAt: now
            )
        }

        guard var newItem = builtItem else {
            return nil
        }

        // 去重并保留原置顶状态
        if let existingIndex = items.firstIndex(where: { Self.isSameContent($0, newItem) }) {
            newItem.isPinned = items[existingIndex].isPinned
            items.remove(at: existingIndex)
        }

        if newItem.isPinned {
            items.insert(newItem, at: 0)
        } else {
            let firstUnpinnedIndex = items.firstIndex(where: { !$0.isPinned }) ?? 0
            items.insert(newItem, at: firstUnpinnedIndex)
        }

        let maxLimit = max(1, maxItemsOverride ?? settingsStore.settings.clipboardMaxItems)
        if items.count > maxLimit {
            items = Array(items.prefix(maxLimit))
        }

        store.replaceAll(items)
        return newItem
    }

    public func startMonitoring(interval: TimeInterval = 0.6) {
        stopMonitoring()
        lastObservedChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: max(0.25, interval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboardOnce()
            }
        }
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func pollPasteboardOnce(now: Date = Date()) {
        purgeExpiredItems(now: now)

        let pb = NSPasteboard.general
        guard pb.changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = pb.changeCount

        let allTypes = (pb.types ?? []).map(\.rawValue)
        let frontApp = NSWorkspace.shared.frontmostApplication
        let fileURLs = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let strValue = pb.string(forType: .string)

        var pngData: Data?
        if fileURLs.isEmpty && (strValue == nil || strValue?.isEmpty == true) {
            if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff) {
                pngData = rep.representation(using: .png, properties: [:])
            } else {
                pngData = pb.data(forType: .png)
            }
        }

        let item = ingestPasteboardSnapshot(
            types: allTypes,
            stringValue: strValue,
            fileURLs: fileURLs,
            imagePNGData: pngData,
            sourceAppBundleID: frontApp?.bundleIdentifier,
            sourceAppName: frontApp?.localizedName,
            now: now
        )

        // 若链接被自动净化，回写干净链接至系统剪贴板并同步计数防止循环
        if let item, item.wasURLCleaned {
            pb.clearContents()
            pb.setString(item.textContent, forType: .string)
            lastObservedChangeCount = pb.changeCount
        }
    }

    public func purgeExpiredItems(now: Date = Date()) {
        let autoClearMinutes = settingsStore.settings.clipboardAutoClearMinutes
        guard autoClearMinutes > 0 else { return }
        let maxAge = TimeInterval(autoClearMinutes * 60)
        let before = items.count
        items.removeAll { !$0.isPinned && now.timeIntervalSince($0.createdAt) >= maxAge }
        if items.count != before {
            store.replaceAll(items)
        }
    }

    public func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isPinned.toggle()
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        items = pinned + unpinned
        store.replaceAll(items)
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        store.replaceAll(items)
    }

    public func clearAll(keepPinned: Bool = false) {
        if keepPinned {
            items.removeAll { !$0.isPinned }
        } else {
            items.removeAll()
        }
        store.replaceAll(items)
    }

    public func copyToPasteboard(_ item: ClipboardHistoryItem, simulatePaste: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text, .url:
            pb.setString(item.textContent, forType: .string)
        case .file:
            let urls = item.fileURLPaths.map { NSURL(fileURLWithPath: $0) }
            pb.writeObjects(urls)
        case .image:
            if let data = item.imageThumbnailPNG, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        }
        lastObservedChangeCount = pb.changeCount

        if simulatePaste, AXIsProcessTrusted() {
            Self.postCommandVKeystroke()
        }
    }

    public func presentPicker() {
        ClipboardPickerPanelController.shared.present(with: self)
    }

    public func dismissPicker() {
        ClipboardPickerPanelController.shared.dismiss()
    }

    private static func isSameContent(_ lhs: ClipboardHistoryItem, _ rhs: ClipboardHistoryItem) -> Bool {
        guard lhs.kind == rhs.kind else { return false }
        switch lhs.kind {
        case .text, .url:
            return lhs.textContent == rhs.textContent
        case .file:
            return lhs.fileURLPaths == rhs.fileURLPaths
        case .image:
            return lhs.imageThumbnailPNG == rhs.imageThumbnailPNG
        }
    }

    private static func makeThumbnailPNG(from data: Data, maxPixel: CGFloat) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1.0, maxPixel / max(size.width, size.height))
        let targetW = max(1, Int((size.width * scale).rounded()))
        let targetH = max(1, Int((size.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetW,
            pixelsHigh: targetH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: targetW * 4,
            bitsPerPixel: 32
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(x: 0, y: 0, width: targetW, height: targetH))
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    private static func describeImageDimensions(from data: Data) -> String {
        if let rep = NSBitmapImageRep(data: data), rep.pixelsWide > 0 {
            return "剪贴板图片 (\(rep.pixelsWide)×\(rep.pixelsHigh))"
        }
        return "剪贴板图片"
    }

    private static func postCommandVKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // ANSI 'V'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
