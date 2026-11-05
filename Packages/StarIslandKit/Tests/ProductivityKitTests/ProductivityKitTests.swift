import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import IslandCore
@testable import ProductivityKit

final class ProductivityKitTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarIsland-ProductivityKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - 1. SmartCodeDetector OTP 正反例单测（Review Focus #1）

    func testDetectOTPRejectsDiscordPlainChatNumberRegression() {
        let result = SmartCodeDetector.detectOTP(
            title: "yetone (#general, Text Channels)",
            body: "端口改成了 3068 可以试试",
            appBundleID: "com.hnc.Discord"
        )
        XCTAssertNil(result, "Discord 普通聊天中的端口号数字绝不能误识别为验证码")
    }

    func testDetectOTPRejectsYearTimeAndCurrencyAmounts() {
        XCTAssertNil(
            SmartCodeDetector.detectOTP(title: "文档通知", body: "2026年工作报告", appBundleID: "com.tencent.xinWeChat"),
            "纯年份绝不能识别为验证码"
        )
        XCTAssertNil(
            SmartCodeDetector.detectOTP(title: "日程提醒", body: "下午 14:30 开会", appBundleID: "com.apple.iCal"),
            "时间格式绝不能识别为验证码"
        )
        XCTAssertNil(
            SmartCodeDetector.detectOTP(title: "账单通知", body: "消费 1280 元", appBundleID: "com.apple.MobileSMS"),
            "消费金额绝不能识别为验证码"
        )
        XCTAssertNil(
            SmartCodeDetector.detectOTP(title: "安全码账单通知", body: "2026年 14:30 消费 ¥1299 元", appBundleID: "com.apple.MobileSMS"),
            "即使标题含语义词，正文仅有年份/时间/金额时也必须返回 nil"
        )
    }

    func testDetectOTPExtractsChineseVerificationCode() {
        let detected = SmartCodeDetector.detectOTP(
            title: "信息",
            body: "【星岛】您的登录验证码为 839201，5分钟内有效。",
            appBundleID: "com.apple.MobileSMS"
        )
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.code, "839201")
    }

    func testDetectOTPExtractsEnglishGitHubAuthenticationCode() {
        let detected = SmartCodeDetector.detectOTP(
            title: "GitHub",
            body: "Your GitHub authentication code is 492817",
            appBundleID: "com.apple.mail"
        )
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.code, "492817")
    }

    func testDetectOTPIgnoresBankCardTailAndCurrencyWhenExtractingRealCode() {
        let detected = SmartCodeDetector.detectOTP(
            title: "招商银行",
            body: "您尾号 6842 的储蓄卡于 2026年 14:30 发起人民币 1280 元支付，交易验证码 739104，5分钟内有效。",
            appBundleID: "com.apple.MobileSMS"
        )
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.code, "739104", "必须跳过卡尾号、年份、时间与金额，精准提取 6 位验证码")
    }

    // MARK: - 2. SmartInboxCoordinator 去重防二次弹窗单测（Review Focus #1）

    @MainActor
    func testSmartInboxCoordinatorDeduplicatesRepeatedOTPNotification() {
        let storeURL = tempDir.appendingPathComponent("consumed-otp.json")
        let settingsURL = tempDir.appendingPathComponent("settings-otp.json")
        let consumedStore = ConsumedEventStore(fileURL: storeURL)
        let settingsStore = SettingsStore(fileURL: settingsURL)
        settingsStore.settings.enableSmartOTP = true
        settingsStore.settings.autoCopyOTP = true
        let stateMachine = IslandStateMachine()

        var copiedCodes: [String] = []
        let coordinator = SmartInboxCoordinator(
            consumedStore: consumedStore,
            stateMachine: stateMachine,
            settingsStore: settingsStore,
            pasteboardWriter: { code in
                copiedCodes.append(code)
            }
        )

        let firstAccepted = coordinator.ingestNotification(
            appBundleID: "com.apple.MobileSMS",
            appName: "信息",
            title: "10690000",
            body: "【星岛】您的登录验证码为 839201，5分钟内有效。"
        )
        XCTAssertTrue(firstAccepted, "首次收到的真实验证码通知应当被消费并提交到灵动岛")
        XCTAssertEqual(copiedCodes, ["839201"])
        XCTAssertEqual(stateMachine.activities.count, 1)
        XCTAssertEqual(stateMachine.primaryActivity?.category, .otp)
        XCTAssertEqual(stateMachine.primaryActivity?.actionPayload, "839201")
        XCTAssertEqual(stateMachine.displayState, .alertHUD)

        // 模拟第一次弹窗已关闭后，通知中心再次重复推送完全相同的通知
        if let firstID = stateMachine.primaryActivity?.id {
            stateMachine.dismiss(id: firstID)
        }
        XCTAssertEqual(stateMachine.displayState, .compact)

        let secondAccepted = coordinator.ingestNotification(
            appBundleID: "com.apple.MobileSMS",
            appName: "信息",
            title: "10690000",
            body: "【星岛】您的登录验证码为 839201，5分钟内有效。"
        )
        XCTAssertFalse(secondAccepted, "相同指纹验证码第二次到达必须被 ConsumedEventStore 拦截并返回 false")
        XCTAssertTrue(stateMachine.activities.isEmpty, "重复验证码绝不能再次触发灵动岛弹窗")
        XCTAssertEqual(stateMachine.displayState, .compact)
        XCTAssertEqual(copiedCodes.count, 1, "重复验证码不应重复改写剪贴板")
    }

    // MARK: - 3. SmartCodeDetector 快递单号识别单测

    func testDetectParcelRecognizesSFExpressAndUPS() {
        let sf = SmartCodeDetector.detectParcel(in: "您的星岛周边已发货，顺丰速运单号：SF1384920571829，请注意查收。")
        XCTAssertNotNil(sf)
        XCTAssertEqual(sf?.trackingNumber, "SF1384920571829")
        XCTAssertTrue(sf?.carrierName.contains("顺丰") == true)

        let ups = SmartCodeDetector.detectParcel(in: "Your package has shipped with tracking 1Z999AA10123456784 via UPS.")
        XCTAssertNotNil(ups)
        XCTAssertEqual(ups?.trackingNumber, "1Z999AA10123456784")
        XCTAssertEqual(ups?.carrierName, "UPS")

        XCTAssertNil(SmartCodeDetector.detectParcel(in: "今天天气不错，下午三点喝咖啡"))
    }

    // MARK: - 4. ClipboardManager 隐私跳过、去重与截断单测（Review Focus #2）

    @MainActor
    func testClipboardManagerSkipsConcealedAndTransientTypesAndDeduplicatesWithMaxItems() {
        let dbURL = tempDir.appendingPathComponent("clipboard.sqlite3")
        let settingsURL = tempDir.appendingPathComponent("settings-clip.json")
        let settingsStore = SettingsStore(fileURL: settingsURL)
        settingsStore.settings.enableClipboardHistory = true
        settingsStore.settings.clipboardMaxItems = 3

        let manager = ClipboardManager(databaseURL: dbURL, settingsStore: settingsStore)

        // 密码管理器隐私标记必须跳过
        let concealed = manager.ingestPasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            stringValue: "MySuperSecretPassword!2026"
        )
        XCTAssertNil(concealed)
        XCTAssertTrue(manager.items.isEmpty)

        let transient = manager.ingestPasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.TransientType"],
            stringValue: "TransientAutoFillToken"
        )
        XCTAssertNil(transient)
        XCTAssertTrue(manager.items.isEmpty)

        // 普通文本正常入库、去重置顶并按 maxItems=3 截断
        _ = manager.ingestPasteboardSnapshot(types: ["public.utf8-plain-text"], stringValue: "第一条文本")
        _ = manager.ingestPasteboardSnapshot(types: ["public.utf8-plain-text"], stringValue: "第二条文本")
        _ = manager.ingestPasteboardSnapshot(types: ["public.utf8-plain-text"], stringValue: "第一条文本")
        XCTAssertEqual(manager.items.map(\.textContent), ["第一条文本", "第二条文本"], "重复复制相同文本应当去重并移至最前")

        _ = manager.ingestPasteboardSnapshot(types: ["public.utf8-plain-text"], stringValue: "第三条文本")
        _ = manager.ingestPasteboardSnapshot(types: ["public.utf8-plain-text"], stringValue: "第四条文本")
        XCTAssertEqual(
            manager.items.map(\.textContent),
            ["第四条文本", "第三条文本", "第一条文本"],
            "超出 clipboardMaxItems 时应当截断最旧条目"
        )
    }

    @MainActor
    func testClipboardManagerCleansDirtyURLAndPurgesExpiredUnpinnedItems() {
        let dbURL = tempDir.appendingPathComponent("clipboard-expire.sqlite3")
        let settingsURL = tempDir.appendingPathComponent("settings-expire.json")
        let settingsStore = SettingsStore(fileURL: settingsURL)
        settingsStore.settings.enableClipboardHistory = true
        settingsStore.settings.enableCleanURL = true
        settingsStore.settings.clipboardAutoClearMinutes = 5

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = ClipboardManager(databaseURL: dbURL, settingsStore: settingsStore)

        let urlItem = manager.ingestPasteboardSnapshot(
            types: ["public.utf8-plain-text"],
            stringValue: "https://example.com/post?id=99&utm_source=twitter&fbclid=xyz",
            now: baseDate
        )
        XCTAssertEqual(urlItem?.kind, .url)
        XCTAssertEqual(urlItem?.textContent, "https://example.com/post?id=99")
        XCTAssertTrue(urlItem?.wasURLCleaned == true)

        let pinnedItem = manager.ingestPasteboardSnapshot(
            types: ["public.utf8-plain-text"],
            stringValue: "常驻置顶备忘",
            now: baseDate
        )
        if let pinID = pinnedItem?.id {
            manager.togglePin(id: pinID)
        }

        // 超过 5 分钟后执行过期清理：未置顶项清除，置顶项保留
        manager.purgeExpiredItems(now: baseDate.addingTimeInterval(360))
        XCTAssertEqual(manager.items.map(\.textContent), ["常驻置顶备忘"])
    }

    // MARK: - 5. URLCleaner 追踪参数剥离单测（Review Focus #2）

    func testURLCleanerStripsTrackingParamsAndPreservesNormalQuery() {
        let dirty = "https://shop.example.com/product/detail?id=42&utm_source=newsletter&utm_medium=email&fbclid=IwAR123&gclid=Cj0KC&spm=a21bo.jianhua&vd_source=8899aa&page=2"
        let cleaned = URLCleaner.clean(dirty)
        XCTAssertEqual(cleaned, "https://shop.example.com/product/detail?id=42&page=2")

        let allTracking = "https://www.bilibili.com/video/BV1xx411c7mD?spm_id_from=333.1007&vd_source=abcdef123456"
        XCTAssertEqual(URLCleaner.clean(allTracking), "https://www.bilibili.com/video/BV1xx411c7mD")

        let alreadyClean = "https://shop.example.com/product/detail?id=42&page=2"
        XCTAssertNil(URLCleaner.clean(alreadyClean), "无任何追踪参数时必须返回 nil")
    }

    // MARK: - 6. MediaToolbox 本地图片真实压缩单测

    func testMediaToolboxCompressImageProducesValidOutput() throws {
        let sourcePNG = tempDir.appendingPathComponent("sample-800x600.png")
        try Self.writeTestBitmapPNG(to: sourcePNG, width: 800, height: 600)

        let jpegReport = try MediaToolbox.compressImage(
            at: sourcePNG,
            quality: 0.72,
            maxDimension: 640
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpegReport.outputURL.path))
        XCTAssertGreaterThan(jpegReport.originalBytes, 0)
        XCTAssertGreaterThan(jpegReport.optimizedBytes, 0)

        guard let imgSource = CGImageSourceCreateWithURL(jpegReport.outputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else {
            XCTFail("压缩输出的图像文件必须能够被 ImageIO 正常解码读取")
            return
        }
        XCTAssertEqual(cgImage.width, 640)
        XCTAssertEqual(cgImage.height, 480)

        let pngOutURL = tempDir.appendingPathComponent("sample-recompressed.png")
        let pngReport = try MediaToolbox.compressImage(
            at: sourcePNG,
            quality: 0.8,
            maxDimension: 400,
            format: .png,
            outputURL: pngOutURL
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngReport.outputURL.path))
        XCTAssertGreaterThan(pngReport.optimizedBytes, 0)
    }

    // MARK: - 7. VisionOCRService 离线文字识别单测

    func testVisionOCRServiceRecognizesRenderedTextInCGImage() async throws {
        let cgImage = try Self.makeRenderedTextCGImage(text: "STARISLAND 2026", width: 960, height: 240)
        let recognized = try await VisionOCRService.recognizeText(in: cgImage)
        XCTAssertTrue(
            recognized.uppercased().contains("STARISLAND"),
            "Vision 离线 OCR 应当识别出 STARISLAND，实际结果：\(recognized)"
        )
    }

    // MARK: - 8. DropzoneShelfManager 与 PDF 压缩补充单测

    @MainActor
    func testDropzoneShelfManagerAddsDeduplicatesAndRemovesFiles() throws {
        let shelfFile = tempDir.appendingPathComponent("shelf.json")
        let settingsURL = tempDir.appendingPathComponent("settings-shelf.json")
        let stateMachine = IslandStateMachine()
        let settingsStore = SettingsStore(fileURL: settingsURL)
        let shelf = DropzoneShelfManager(
            storageURL: shelfFile,
            stateMachine: stateMachine,
            settingsStore: settingsStore
        )

        let sampleFile = tempDir.appendingPathComponent("demo.txt")
        try Data("星岛文件暂存测试".utf8).write(to: sampleFile)

        XCTAssertEqual(shelf.addFiles([sampleFile, sampleFile]), 1)
        XCTAssertEqual(shelf.items.count, 1)
        XCTAssertEqual(shelf.items.first?.fileName, "demo.txt")

        if let first = shelf.items.first {
            shelf.remove(first.id)
        }
        XCTAssertTrue(shelf.items.isEmpty)
    }

    func testMediaToolboxCompressPDFProducesReadablePDF() throws {
        let inputPDF = tempDir.appendingPathComponent("sample.pdf")
        try Self.writeTestPDF(to: inputPDF)

        let report = try MediaToolbox.compressPDF(at: inputPDF)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.outputURL.path))
        let doc = PDFDocument(url: report.outputURL)
        XCTAssertEqual(doc?.pageCount, 1)
    }

    // MARK: - 测试图像/PDF辅助生成器

    private static func writeTestBitmapPNG(to url: URL, width: Int, height: Int) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "ProductivityKitTests", code: 1)
        }

        for y in stride(from: 0, to: height, by: 20) {
            for x in stride(from: 0, to: width, by: 20) {
                let r = CGFloat((x * 37 + y * 13) % 255) / 255.0
                let g = CGFloat((x * 17 + y * 53) % 255) / 255.0
                let b = CGFloat((x * 29 + y * 7) % 255) / 255.0
                ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
                ctx.fill(CGRect(x: x, y: y, width: 20, height: 20))
            }
        }

        guard let cgImage = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "ProductivityKitTests", code: 2)
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "ProductivityKitTests", code: 3)
        }
    }

    private static func makeRenderedTextCGImage(text: String, width: Int, height: Int) throws -> CGImage {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
            throw NSError(domain: "ProductivityKitTests", code: 4)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 72),
            .foregroundColor: NSColor.black,
            .kern: 2.0,
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        let origin = NSPoint(
            x: (CGFloat(width) - textSize.width) / 2.0,
            y: (CGFloat(height) - textSize.height) / 2.0
        )
        attrString.draw(at: origin)

        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else {
            throw NSError(domain: "ProductivityKitTests", code: 5)
        }
        return cgImage
    }

    private static func writeTestPDF(to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "ProductivityKitTests", code: 6)
        }
        pdfContext.beginPDFPage(nil)
        pdfContext.setFillColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1.0)
        pdfContext.fill(CGRect(x: 50, y: 50, width: 512, height: 692))
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }

    func testURLCleanerPreservesLegitimateFromQueryParamWhileStrippingTracking() {
        let raw = "https://flights.example.com/search?from=SHA&to=PEK&utm_source=weibo&from_spmid=333.999"
        let cleaned = URLCleaner.clean(raw)
        XCTAssertEqual(cleaned, "https://flights.example.com/search?from=SHA&to=PEK")
    }
}
