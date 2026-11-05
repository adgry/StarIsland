import AppKit
import Combine
import Foundation
import IslandCore
import Network

@MainActor
public final class LANContinuityServer: ObservableObject {
    public static let shared = LANContinuityServer()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var listeningPort: UInt16
    @Published public private(set) var localIPAddress: String
    @Published public private(set) var currentPIN: String
    @Published public private(set) var pairingURL: URL?
    @Published public private(set) var qrCodeImage: NSImage?
    @Published public private(set) var connectedSessions: [PairedDeviceSession] = []
    @Published public private(set) var sharedFiles: [SharedTransferFile] = []
    @Published public private(set) var receivedFiles: [SharedTransferFile] = []
    @Published public var statusMessage: String = "准备就绪"

    public let tokenManager: PairingTokenManager
    public var uploadDirectoryURL: URL
    public var onMediaCommand: (@MainActor (RemoteMediaCommand) -> Void)?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let networkQueue = DispatchQueue(label: "com.adgry.starisland.lan-continuity", qos: .userInitiated)
    private var listener: NWListener?

    private static let concealedPasteboardType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private nonisolated static let maxUploadBytes = 256 * 1024 * 1024

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        uploadDirectoryURL: URL? = nil,
        tokenManager: PairingTokenManager = PairingTokenManager()
    ) {
        let resolvedSettings = settingsStore ?? .shared
        let resolvedState = stateMachine ?? .shared
        self.settingsStore = resolvedSettings
        self.stateMachine = resolvedState
        self.tokenManager = tokenManager
        self.currentPIN = tokenManager.currentPIN
        self.listeningPort = resolvedSettings.settings.lanServerPort
        self.localIPAddress = LANAddressDetector.preferredIPv4Address()

        if let uploadDirectoryURL {
            self.uploadDirectoryURL = uploadDirectoryURL
        } else {
            self.uploadDirectoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        }
        rebuildPairingArtifacts()
    }

    public var hostDisplayName: String {
        Host.current().localizedName ?? "星岛 Mac"
    }

    // MARK: - 服务生命周期与 Bonjour 广播

    public func start() {
        stop()

        let configuredPort = settingsStore.settings.lanServerPort
        let nwPort: NWEndpoint.Port = (configuredPort > 0)
            ? (NWEndpoint.Port(rawValue: configuredPort) ?? .any)
            : .any

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let nwListener = try NWListener(using: params, on: nwPort)
            nwListener.service = NWListener.Service(name: hostDisplayName, type: "_starisland._tcp")

            nwListener.stateUpdateHandler = { [weak self, weak nwListener] newState in
                let actualPort = nwListener?.port?.rawValue
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch newState {
                    case .ready:
                        if let actualPort {
                            self.listeningPort = actualPort
                        }
                        self.localIPAddress = LANAddressDetector.preferredIPv4Address()
                        self.isRunning = true
                        self.statusMessage = "正在监听 \(self.localIPAddress):\(self.listeningPort)"
                        self.rebuildPairingArtifacts()
                    case .failed(let error):
                        self.isRunning = false
                        self.statusMessage = "局域网服务异常：\(error.localizedDescription)"
                    case .cancelled:
                        self.isRunning = false
                        self.statusMessage = "已停止"
                    default:
                        break
                    }
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                self?.acceptConnection(connection)
            }

            self.listener = nwListener
            nwListener.start(queue: networkQueue)
        } catch {
            isRunning = false
            statusMessage = "无法绑定端口 \(configuredPort)：\(error.localizedDescription)"
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        statusMessage = "已停止"
    }

    @discardableResult
    public func refreshPIN() -> String {
        let newPIN = tokenManager.generateNewPIN()
        currentPIN = newPIN
        connectedSessions = []
        rebuildPairingArtifacts()
        return newPIN
    }

    // MARK: - 共享文件管理

    public func addSharedFiles(_ urls: [URL]) {
        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if sharedFiles.contains(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) {
                continue
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let item = SharedTransferFile(
                name: SafeFilenameSanitizer.sanitize(url.lastPathComponent),
                fileURL: url,
                sizeBytes: size
            )
            sharedFiles.insert(item, at: 0)
        }
    }

    public func removeSharedFile(id: String) {
        sharedFiles.removeAll { $0.id == id }
    }

    // MARK: - HTTP/1.1 路由与安全鉴权核心

    public func handleHTTPRequest(_ request: LANHTTPRequest) -> LANHTTPResponse {
        let cleanPath = request.path.isEmpty ? "/" : request.path

        if request.method == "GET" && (cleanPath == "/" || cleanPath == "/index.html") {
            let html = MobileWebPortalHTML.render(hostName: hostDisplayName)
            return LANHTTPResponse(
                statusCode: 200,
                statusText: "OK",
                headers: [
                    "Content-Type": "text/html; charset=utf-8",
                    "Cache-Control": "no-store"
                ],
                body: Data(html.utf8)
            )
        }

        if request.method == "GET" && cleanPath == "/favicon.ico" {
            return LANHTTPResponse(statusCode: 204, statusText: "No Content")
        }

        if request.method == "POST" && cleanPath == "/api/pair" {
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let pin = json["pin"] as? String else {
                return .unauthorized(message: "配对请求格式错误")
            }
            let deviceName = (json["deviceName"] as? String) ?? "手机浏览器"
            guard let sessionToken = tokenManager.issueSessionToken(forPIN: pin, deviceName: deviceName) else {
                if currentPIN != tokenManager.currentPIN {
                    currentPIN = tokenManager.currentPIN
                    rebuildPairingArtifacts()
                }
                return .unauthorized(message: "6 位安全配对码错误或已自动刷新，请查看灵动岛最新配对码")
            }
            currentPIN = tokenManager.currentPIN
            rebuildPairingArtifacts()
            connectedSessions = tokenManager.activeSessions()
            notifyIsland(
                title: "\(deviceName) 已连接星岛",
                subtitle: "局域网双向快传与剪贴板同步已就绪",
                icon: "iphone.radiowaves.left.and.right"
            )
            return .json([
                "token": sessionToken,
                "hostName": hostDisplayName
            ])
        }

        let bearerToken = PairingTokenManager.extractBearerToken(from: request.headerValue(for: "Authorization"))
        guard tokenManager.isValidSession(bearerToken) else {
            return .unauthorized()
        }
        connectedSessions = tokenManager.activeSessions()

        switch (request.method, cleanPath) {
        case ("GET", "/api/status"):
            return .json(["ok": true, "hostName": hostDisplayName])

        case ("GET", "/api/files"):
            let items: [[String: Any]] = sharedFiles.map { item in
                [
                    "id": item.id,
                    "name": item.name,
                    "sizeBytes": item.sizeBytes
                ]
            }
            return .json(["files": items])

        case ("POST", "/api/upload"):
            return handleFileUpload(request)

        case ("GET", "/api/clipboard"):
            return handleReadClipboard()

        case ("POST", "/api/clipboard"):
            return handleWriteClipboard(request)

        case ("POST", "/api/media"):
            return handleRemoteMedia(request)

        default:
            if request.method == "GET", cleanPath.hasPrefix("/api/files/") {
                let rawID = String(cleanPath.dropFirst("/api/files/".count))
                let decodedID = rawID.removingPercentEncoding ?? rawID
                return handleDownloadSharedFile(id: decodedID)
            }
            return .json(["error": "未找到请求的接口"], statusCode: 404, statusText: "Not Found")
        }
    }

    // MARK: - 业务路由实现

    private func handleFileUpload(_ request: LANHTTPRequest) -> LANHTTPResponse {
        let rawHeaderName = request.headerValue(for: "X-File-Name") ?? ""
        let decodedName = rawHeaderName.removingPercentEncoding ?? rawHeaderName

        do {
            try FileManager.default.createDirectory(at: uploadDirectoryURL, withIntermediateDirectories: true)
            let destinationURL = SafeFilenameSanitizer.uniqueDestinationURL(
                in: uploadDirectoryURL,
                rawFilename: decodedName
            )
            try request.body.write(to: destinationURL, options: .atomic)

            let savedRecord = SharedTransferFile(
                name: destinationURL.lastPathComponent,
                fileURL: destinationURL,
                sizeBytes: Int64(request.body.count)
            )
            receivedFiles.insert(savedRecord, at: 0)
            if receivedFiles.count > 50 {
                receivedFiles.removeLast(receivedFiles.count - 50)
            }

            notifyIsland(
                title: "收到手机快传文件",
                subtitle: destinationURL.lastPathComponent,
                icon: "arrow.down.doc.fill"
            )

            return .json([
                "ok": true,
                "savedName": destinationURL.lastPathComponent,
                "sizeBytes": request.body.count
            ])
        } catch {
            return .json(
                ["error": "保存上传文件失败：\(error.localizedDescription)"],
                statusCode: 500,
                statusText: "Internal Server Error"
            )
        }
    }

    private func handleDownloadSharedFile(id: String) -> LANHTTPResponse {
        guard let item = sharedFiles.first(where: { $0.id == id }),
              let data = try? Data(contentsOf: item.fileURL) else {
            return .json(["error": "共享文件不存在或已被移除"], statusCode: 404, statusText: "Not Found")
        }
        let encodedFilename = item.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "download"
        return LANHTTPResponse(
            statusCode: 200,
            statusText: "OK",
            headers: [
                "Content-Type": "application/octet-stream",
                "Content-Disposition": "attachment; filename*=UTF-8''\(encodedFilename)"
            ],
            body: data
        )
    }

    private func handleReadClipboard() -> LANHTTPResponse {
        let pb = NSPasteboard.general
        let sensitiveTypes: Set<NSPasteboard.PasteboardType> = [
            Self.concealedPasteboardType,
            NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
            NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
        ]
        if let types = pb.types, types.contains(where: { sensitiveTypes.contains($0) }) {
            return .json(["text": ""])
        }
        let text = pb.string(forType: .string) ?? ""
        return .json(["text": text])
    }

    private func handleWriteClipboard(_ request: LANHTTPRequest) -> LANHTTPResponse {
        guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let text = json["text"] as? String else {
            return .json(["error": "无效的剪贴板载荷"], statusCode: 400, statusText: "Bad Request")
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        notifyIsland(
            title: "已同步手机剪贴板",
            subtitle: String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)),
            icon: "doc.on.clipboard.fill"
        )
        return .json(["ok": true])
    }

    private func handleRemoteMedia(_ request: LANHTTPRequest) -> LANHTTPResponse {
        guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let rawCmd = json["command"] as? String,
              let command = RemoteMediaCommand(rawValue: rawCmd) else {
            return .json(["error": "不支持的媒体控制指令"], statusCode: 400, statusText: "Bad Request")
        }

        if let onMediaCommand {
            onMediaCommand(command)
        } else {
            Self.postSystemMediaKey(for: command)
        }
        return .json(["ok": true, "command": command.rawValue])
    }

    // MARK: - TCP 流管理与媒体键派发

    private func rebuildPairingArtifacts() {
        localIPAddress = LANAddressDetector.preferredIPv4Address()
        let port = listeningPort > 0 ? listeningPort : settingsStore.settings.lanServerPort
        let urlString = "http://\(localIPAddress):\(port)/?pin=\(currentPIN)"
        pairingURL = URL(string: urlString)
        qrCodeImage = QRCodeGenerator.makeImage(from: urlString, dimension: 280)
    }

    private func notifyIsland(title: String, subtitle: String, icon: String) {
        let activity = IslandActivityItem(
            id: "continuity.event",
            category: .continuity,
            title: title,
            subtitle: subtitle,
            iconSymbol: icon,
            priority: .interactive,
            isPeek: true,
            allowsOnLockScreen: false,
            autoDismissAfter: 3.5
        )
        stateMachine.submit(activity)
    }

    private nonisolated func acceptConnection(_ connection: NWConnection) {
        let accumulator = HTTPStreamAccumulator(maxBodyBytes: Self.maxUploadBytes)
        connection.start(queue: networkQueue)
        receiveNextChunk(on: connection, accumulator: accumulator)
    }

    private nonisolated func receiveNextChunk(on connection: NWConnection, accumulator: HTTPStreamAccumulator) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let chunk, !chunk.isEmpty {
                switch accumulator.append(chunk) {
                case .needMoreData:
                    if isComplete {
                        connection.cancel()
                    } else {
                        self.receiveNextChunk(on: connection, accumulator: accumulator)
                    }
                    return

                case .payloadTooLarge:
                    let resp = LANHTTPResponse.json(
                        ["error": "上传文件体积超过单次上限"],
                        statusCode: 413,
                        statusText: "Payload Too Large"
                    )
                    self.sendAndClose(resp, over: connection)
                    return

                case .badRequest:
                    let resp = LANHTTPResponse.json(
                        ["error": "无效的 HTTP 请求"],
                        statusCode: 400,
                        statusText: "Bad Request"
                    )
                    self.sendAndClose(resp, over: connection)
                    return

                case .complete(let parsedRequest):
                    Task { @MainActor [weak self] in
                        guard let self else {
                            connection.cancel()
                            return
                        }
                        let response = self.handleHTTPRequest(parsedRequest)
                        self.sendAndClose(response, over: connection)
                    }
                    return
                }
            }

            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private nonisolated func sendAndClose(_ response: LANHTTPResponse, over connection: NWConnection) {
        let wireData = response.serializedHTTPData()
        connection.send(content: wireData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func postSystemMediaKey(for command: RemoteMediaCommand) {
        let keyCode: Int32
        switch command {
        case .volumeUp: keyCode = 0
        case .volumeDown: keyCode = 1
        case .playPause: keyCode = 16
        case .next: keyCode = 17
        case .previous: keyCode = 18
        case .lockScreen:
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            proc.arguments = ["displaysleepnow"]
            try? proc.run()
            return
        }

        for isKeyDown in [true, false] {
            let flags: UInt = isKeyDown ? 0xa00 : 0xb00
            let data1 = Int((keyCode << 16) | (isKeyDown ? 0x0a00 : 0x0b00))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: flags),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
