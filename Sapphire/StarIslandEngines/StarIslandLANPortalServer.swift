//
//  StarIslandLANPortalServer.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import Foundation
import Network

struct StarIslandHTTPRequest: Sendable {
    var method: String
    var path: String
    var queryItems: [String: String] = [:]
    var headers: [String: String] = [:]
    var body: Data = Data()

    func headerValue(for name: String) -> String? {
        let lower = name.lowercased()
        return headers.first { $0.key.lowercased() == lower }?.value
    }
}

struct StarIslandHTTPResponse: Sendable {
    var statusCode: Int
    var statusText: String
    var headers: [String: String] = [:]
    var body: Data = Data()

    static func json(_ obj: [String: Any], statusCode: Int = 200, statusText: String = "OK") -> StarIslandHTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        return StarIslandHTTPResponse(
            statusCode: statusCode,
            statusText: statusText,
            headers: ["Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store"],
            body: data
        )
    }

    static func unauthorized(message: String = "未授权访问，请输入 6 位安全配对码") -> StarIslandHTTPResponse {
        .json(["error": message], statusCode: 401, statusText: "Unauthorized")
    }

    func serializedHTTPData() -> Data {
        var hdrs = headers
        hdrs["Content-Length"] = "\(body.count)"
        hdrs["Connection"] = "close"
        var head = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (k, v) in hdrs { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        var out = Data(head.utf8)
        out.append(body)
        return out
    }
}

struct StarIslandSharedFile: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let fileURL: URL
    let sizeBytes: Int64
}

private final class StarIslandHTTPAccumulator: @unchecked Sendable {
    enum Step { case more, complete(StarIslandHTTPRequest), tooLarge, bad }
    private static let delim = Data("\r\n\r\n".utf8)
    private let maxBody: Int
    private var buf = Data()
    private var head: (method: String, path: String, headers: [String: String], len: Int, bodyStart: Int)?

    init(maxBody: Int) { self.maxBody = maxBody }

    func append(_ chunk: Data) -> Step {
        buf.append(chunk)
        if head == nil {
            guard let r = buf.range(of: Self.delim) else { return buf.count > 32768 ? .bad : .more }
            guard let text = String(data: buf.subdata(in: 0..<r.lowerBound), encoding: .utf8) else { return .bad }
            let lines = text.components(separatedBy: "\r\n")
            guard let first = lines.first else { return .bad }
            let parts = first.split(separator: " ")
            guard parts.count >= 2 else { return .bad }
            let rawTarget = String(parts[1])
            let path = URLComponents(string: rawTarget)?.path ?? rawTarget
            var hdrs: [String: String] = [:]
            for line in lines.dropFirst() where !line.isEmpty {
                if let idx = line.firstIndex(of: ":") {
                    hdrs[line[..<idx].trimmingCharacters(in: .whitespaces)] = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
                }
            }
            let len = max(0, Int(hdrs.first { $0.key.lowercased() == "content-length" }?.value ?? "0") ?? 0)
            if len > maxBody { return .tooLarge }
            head = (String(parts[0]).uppercased(), path.isEmpty ? "/" : path, hdrs, len, r.upperBound)
        }
        guard let h = head else { return .more }
        if buf.count - h.bodyStart < h.len { return .more }
        let body = buf.subdata(in: h.bodyStart..<(h.bodyStart + h.len))
        return .complete(StarIslandHTTPRequest(method: h.method, path: h.path, headers: h.headers, body: body))
    }
}

@MainActor
final class StarIslandLANPortalServer: ObservableObject {
    static let shared = StarIslandLANPortalServer()

    @Published private(set) var isRunning = false
    @Published private(set) var listeningPort: UInt16 = 58420
    @Published private(set) var localIPAddress: String
    @Published private(set) var currentPIN: String
    @Published private(set) var pairingURL: URL?
    @Published private(set) var qrCodeImage: NSImage?
    @Published private(set) var connectedSessions: [StarIslandPairedSession] = []
    @Published private(set) var sharedFiles: [StarIslandSharedFile] = []
    @Published private(set) var receivedFiles: [StarIslandSharedFile] = []
    @Published private(set) var statusMessage: String = "准备就绪"

    let tokenManager: StarIslandPairingTokenManager
    var uploadDirectoryURL: URL
    var onStateChanged: (@MainActor () -> Void)?

    private let queue = DispatchQueue(label: "com.adgry.starisland.lan-portal", qos: .userInitiated)
    private var listener: NWListener?

    init(uploadDirectoryURL: URL? = nil, tokenManager: StarIslandPairingTokenManager = StarIslandPairingTokenManager()) {
        self.tokenManager = tokenManager
        self.currentPIN = tokenManager.currentPIN
        self.localIPAddress = StarIslandLANAddressDetector.preferredIPv4Address()
        self.uploadDirectoryURL = uploadDirectoryURL
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        rebuildPairingArtifacts()
    }

    var hostDisplayName: String { Host.current().localizedName ?? "星岛 Mac" }

    func start() {
        stop()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let port = NWEndpoint.Port(rawValue: 58420) ?? .any
            let nw = try NWListener(using: params, on: port)
            nw.service = NWListener.Service(name: hostDisplayName, type: "_starisland._tcp")
            nw.stateUpdateHandler = { [weak self, weak nw] state in
                let boundPort = nw?.port?.rawValue
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        if let boundPort { self.listeningPort = boundPort }
                        self.isRunning = true
                        self.rebuildPairingArtifacts()
                        self.statusMessage = "监听中 \(self.localIPAddress):\(self.listeningPort)"
                        self.onStateChanged?()
                    case .failed(let err):
                        self.isRunning = false
                        self.statusMessage = "服务异常：\(err.localizedDescription)"
                        self.onStateChanged?()
                    case .cancelled:
                        self.isRunning = false
                        self.statusMessage = "已停止"
                        self.onStateChanged?()
                    default: break
                    }
                }
            }
            nw.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            listener = nw
            nw.start(queue: queue)
        } catch {
            isRunning = false
            statusMessage = "启动失败：\(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        statusMessage = "已停止"
        onStateChanged?()
    }

    @discardableResult
    func refreshPIN() -> String {
        currentPIN = tokenManager.generateNewPIN()
        connectedSessions = []
        rebuildPairingArtifacts()
        onStateChanged?()
        return currentPIN
    }

    func addSharedFiles(_ urls: [URL]) {
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if sharedFiles.contains(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) { continue }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            sharedFiles.insert(StarIslandSharedFile(id: UUID().uuidString, name: StarIslandSafeFilename.sanitize(url.lastPathComponent), fileURL: url, sizeBytes: size), at: 0)
        }
    }

    func removeSharedFile(id: String) {
        sharedFiles.removeAll { $0.id == id }
    }

    func handleHTTPRequest(_ request: StarIslandHTTPRequest) -> StarIslandHTTPResponse {
        let path = request.path.isEmpty ? "/" : request.path
        if request.method == "GET" && (path == "/" || path == "/index.html") {
            let html = StarIslandLANPortalHTML.render(hostName: hostDisplayName)
            return StarIslandHTTPResponse(statusCode: 200, statusText: "OK", headers: ["Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store"], body: Data(html.utf8))
        }
        if request.method == "GET" && path == "/favicon.ico" {
            return StarIslandHTTPResponse(statusCode: 204, statusText: "No Content")
        }
        if request.method == "POST" && path == "/api/pair" {
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let pin = json["pin"] as? String else {
                return .unauthorized(message: "请求格式错误")
            }
            let dev = (json["deviceName"] as? String) ?? "手机浏览器"
            guard let tok = tokenManager.issueSessionToken(forPIN: pin, deviceName: dev) else {
                currentPIN = tokenManager.currentPIN
                rebuildPairingArtifacts()
                return .unauthorized(message: "6 位配对码错误或已自动轮换")
            }
            currentPIN = tokenManager.currentPIN
            rebuildPairingArtifacts()
            connectedSessions = tokenManager.activeSessions()
            onStateChanged?()
            return .json(["token": tok, "hostName": hostDisplayName])
        }

        let bearer = StarIslandPairingTokenManager.extractBearerToken(from: request.headerValue(for: "Authorization"))
        guard tokenManager.isValidSession(bearer) else { return .unauthorized() }
        connectedSessions = tokenManager.activeSessions()

        switch (request.method, path) {
        case ("GET", "/api/status"):
            return .json(["ok": true, "hostName": hostDisplayName])
        case ("GET", "/api/files"):
            let list = sharedFiles.map { ["id": $0.id, "name": $0.name, "sizeBytes": $0.sizeBytes] as [String: Any] }
            return .json(["files": list])
        case ("POST", "/api/upload"):
            let rawName = (request.headerValue(for: "X-File-Name") ?? "").removingPercentEncoding ?? "transfer.bin"
            do {
                try FileManager.default.createDirectory(at: uploadDirectoryURL, withIntermediateDirectories: true)
                let dest = StarIslandSafeFilename.uniqueDestinationURL(in: uploadDirectoryURL, rawFilename: rawName)
                try request.body.write(to: dest, options: .atomic)
                receivedFiles.insert(StarIslandSharedFile(id: UUID().uuidString, name: dest.lastPathComponent, fileURL: dest, sizeBytes: Int64(request.body.count)), at: 0)
                return .json(["ok": true, "savedName": dest.lastPathComponent, "sizeBytes": request.body.count])
            } catch {
                return .json(["error": error.localizedDescription], statusCode: 500, statusText: "Internal Server Error")
            }
        case ("GET", "/api/clipboard"):
            guard SettingsModel.shared.settings.continuityClipboardSync else { return .json(["text": ""]) }
            let pb = NSPasteboard.general
            let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
            if pb.types?.contains(concealed) == true { return .json(["text": ""]) }
            return .json(["text": pb.string(forType: .string) ?? ""])
        case ("POST", "/api/clipboard"):
            guard SettingsModel.shared.settings.continuityClipboardSync,
                  let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let text = json["text"] as? String else {
                return .json(["error": "剪贴板同步未开启或内容无效"], statusCode: 400, statusText: "Bad Request")
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            NotificationCenter.default.post(name: .continuityClipboardReceived, object: nil)
            return .json(["ok": true])
        case ("POST", "/api/media"):
            guard SettingsModel.shared.settings.continuityMediaControls,
                  let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let cmd = json["command"] as? String else {
                return .json(["error": "无效指令"], statusCode: 400, statusText: "Bad Request")
            }
            dispatchMediaCommand(cmd)
            return .json(["ok": true])
        default:
            if request.method == "GET", path.hasPrefix("/api/files/") {
                let fid = String(path.dropFirst("/api/files/".count)).removingPercentEncoding ?? ""
                guard let item = sharedFiles.first(where: { $0.id == fid }),
                      let data = try? Data(contentsOf: item.fileURL) else {
                    return .json(["error": "文件不存在"], statusCode: 404, statusText: "Not Found")
                }
                let enc = item.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "download"
                return StarIslandHTTPResponse(statusCode: 200, statusText: "OK", headers: ["Content-Type": "application/octet-stream", "Content-Disposition": "attachment; filename*=UTF-8''\(enc)"], body: data)
            }
            return .json(["error": "Not Found"], statusCode: 404, statusText: "Not Found")
        }
    }

    private func rebuildPairingArtifacts() {
        localIPAddress = StarIslandLANAddressDetector.preferredIPv4Address()
        let urlStr = "http://\(localIPAddress):\(listeningPort)/?pin=\(currentPIN)"
        pairingURL = URL(string: urlStr)
        qrCodeImage = StarIslandQRCodeGenerator.makeImage(from: urlStr, dimension: 220)
    }

    private func dispatchMediaCommand(_ cmd: String) {
        switch cmd {
        case "playPause":
            Task { @MainActor in
                if MusicManager.shared.isPlaying {
                    await MusicManager.shared.pause()
                } else {
                    await MusicManager.shared.play()
                }
            }
        case "next":
            Task { @MainActor in await MusicManager.shared.nextTrack() }
        case "previous":
            Task { @MainActor in await MusicManager.shared.previousTrack() }
        case "lockScreen":
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            p.arguments = ["displaysleepnow"]
            try? p.run()
        default: break
        }
    }

    private nonisolated func accept(_ conn: NWConnection) {
        let acc = StarIslandHTTPAccumulator(maxBody: 256 * 1024 * 1024)
        conn.start(queue: queue)
        receiveLoop(conn, acc: acc)
    }

    private nonisolated func receiveLoop(_ conn: NWConnection, acc: StarIslandHTTPAccumulator) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, isComplete, err in
            guard let self else { conn.cancel(); return }
            if let chunk, !chunk.isEmpty {
                switch acc.append(chunk) {
                case .more:
                    if isComplete { conn.cancel() } else { self.receiveLoop(conn, acc: acc) }
                case .tooLarge:
                    self.send(StarIslandHTTPResponse.json(["error": "Payload Too Large"], statusCode: 413, statusText: "Payload Too Large"), on: conn)
                case .bad:
                    self.send(StarIslandHTTPResponse.json(["error": "Bad Request"], statusCode: 400, statusText: "Bad Request"), on: conn)
                case .complete(let req):
                    Task { @MainActor [weak self] in
                        guard let self else { conn.cancel(); return }
                        self.send(self.handleHTTPRequest(req), on: conn)
                    }
                }
                return
            }
            if isComplete || err != nil { conn.cancel() }
        }
    }

    private nonisolated func send(_ resp: StarIslandHTTPResponse, on conn: NWConnection) {
        conn.send(content: resp.serializedHTTPData(), completion: .contentProcessed { _ in conn.cancel() })
    }
}
#endif
