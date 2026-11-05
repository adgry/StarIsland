import Foundation

public struct LANHTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var queryItems: [String: String]
    public var headers: [String: String]
    public var body: Data

    public init(
        method: String,
        path: String,
        queryItems: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.method = method.uppercased()
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    public func headerValue(for name: String) -> String? {
        let lower = name.lowercased()
        return headers.first { $0.key.lowercased() == lower }?.value
    }
}

public struct LANHTTPResponse: Sendable {
    public var statusCode: Int
    public var statusText: String
    public var headers: [String: String]
    public var body: Data

    public init(
        statusCode: Int,
        statusText: String,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.statusCode = statusCode
        self.statusText = statusText
        self.headers = headers
        self.body = body
    }

    public static func json(
        _ object: [String: Any],
        statusCode: Int = 200,
        statusText: String = "OK",
        extraHeaders: [String: String] = [:]
    ) -> LANHTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        var merged: [String: String] = [
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store"
        ]
        for (k, v) in extraHeaders {
            merged[k] = v
        }
        return LANHTTPResponse(statusCode: statusCode, statusText: statusText, headers: merged, body: data)
    }

    public static func unauthorized(message: String = "未授权访问，请先通过 6 位配对码验证") -> LANHTTPResponse {
        .json(
            ["error": message],
            statusCode: 401,
            statusText: "Unauthorized",
            extraHeaders: ["WWW-Authenticate": "Bearer realm=\"StarIsland\""]
        )
    }

    public func serializedHTTPData() -> Data {
        var finalHeaders = headers
        finalHeaders["Content-Length"] = "\(body.count)"
        finalHeaders["Connection"] = "close"

        var headerBlock = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (key, value) in finalHeaders {
            headerBlock += "\(key): \(value)\r\n"
        }
        headerBlock += "\r\n"

        var out = Data(headerBlock.utf8)
        out.append(body)
        return out
    }
}

public struct SharedTransferFile: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let fileURL: URL
    public let sizeBytes: Int64
    public let addedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        fileURL: URL,
        sizeBytes: Int64,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.sizeBytes = sizeBytes
        self.addedAt = addedAt
    }
}

public enum RemoteMediaCommand: String, Codable, CaseIterable, Sendable {
    case playPause
    case next
    case previous
    case volumeUp
    case volumeDown
    case lockScreen
}

final class HTTPStreamAccumulator: @unchecked Sendable {
    enum StepResult {
        case needMoreData
        case complete(LANHTTPRequest)
        case payloadTooLarge
        case badRequest
    }

    private static let headerDelimiter = Data("\r\n\r\n".utf8)
    private static let maxHeaderBytes = 32 * 1024

    private let maxBodyBytes: Int
    private var buffer = Data()
    private var parsedHead: (
        method: String,
        path: String,
        query: [String: String],
        headers: [String: String],
        contentLength: Int,
        bodyStartOffset: Int
    )?

    init(maxBodyBytes: Int) {
        self.maxBodyBytes = maxBodyBytes
    }

    func append(_ data: Data) -> StepResult {
        buffer.append(data)

        if parsedHead == nil {
            guard let delimiterRange = buffer.range(of: Self.headerDelimiter) else {
                return buffer.count > Self.maxHeaderBytes ? .badRequest : .needMoreData
            }
            let headData = buffer.subdata(in: 0..<delimiterRange.lowerBound)
            guard let headText = String(data: headData, encoding: .utf8) else {
                return .badRequest
            }
            let lines = headText.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else { return .badRequest }
            let parts = requestLine.split(separator: " ")
            guard parts.count >= 2 else { return .badRequest }

            let method = String(parts[0])
            let rawTarget = String(parts[1])
            let (path, query) = Self.splitPathAndQuery(rawTarget)

            var headers: [String: String] = [:]
            for line in lines.dropFirst() where !line.isEmpty {
                if let colonIdx = line.firstIndex(of: ":") {
                    let key = line[..<colonIdx].trimmingCharacters(in: .whitespaces)
                    let val = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
                    headers[key] = val
                }
            }

            let contentLengthStr = headers.first { $0.key.lowercased() == "content-length" }?.value ?? "0"
            let contentLength = max(0, Int(contentLengthStr) ?? 0)
            if contentLength > maxBodyBytes {
                return .payloadTooLarge
            }

            parsedHead = (
                method: method,
                path: path,
                query: query,
                headers: headers,
                contentLength: contentLength,
                bodyStartOffset: delimiterRange.upperBound
            )
        }

        guard let head = parsedHead else { return .needMoreData }
        let currentBodyCount = buffer.count - head.bodyStartOffset
        if currentBodyCount < head.contentLength {
            return .needMoreData
        }

        let bodyEnd = head.bodyStartOffset + head.contentLength
        let bodyData = buffer.subdata(in: head.bodyStartOffset..<bodyEnd)
        let req = LANHTTPRequest(
            method: head.method,
            path: head.path,
            queryItems: head.query,
            headers: head.headers,
            body: bodyData
        )
        return .complete(req)
    }

    private static func splitPathAndQuery(_ rawTarget: String) -> (String, [String: String]) {
        guard let comps = URLComponents(string: rawTarget) else {
            return (rawTarget, [:])
        }
        var dict: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            dict[item.name] = item.value ?? ""
        }
        return (comps.path.isEmpty ? "/" : comps.path, dict)
    }
}
