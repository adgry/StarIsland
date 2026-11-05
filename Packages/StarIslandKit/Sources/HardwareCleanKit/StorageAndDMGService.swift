import Combine
import Darwin
import Foundation

/// 系统内存压力等级
public enum SystemMemoryPressureLevel: String, Codable, Equatable, Sendable {
    case normal
    case warning
    case critical

    public var localizedTitle: String {
        switch self {
        case .normal: return "充裕"
        case .warning: return "偏高"
        case .critical: return "吃紧"
        }
    }
}

/// 本机系统盘容量与物理内存压力实时快照
public struct DiskAndMemorySnapshot: Codable, Equatable, Sendable {
    public var totalDiskBytes: Int64
    public var availableDiskBytes: Int64
    public var physicalMemoryBytes: UInt64
    public var usedMemoryBytes: UInt64
    public var memoryPressure: SystemMemoryPressureLevel

    public var usedDiskBytes: Int64 {
        max(0, totalDiskBytes - availableDiskBytes)
    }

    public var diskUsageRatio: Double {
        guard totalDiskBytes > 0 else { return 0 }
        return min(max(Double(usedDiskBytes) / Double(totalDiskBytes), 0.0), 1.0)
    }

    public var memoryUsageRatio: Double {
        guard physicalMemoryBytes > 0 else { return 0 }
        return min(max(Double(usedMemoryBytes) / Double(physicalMemoryBytes), 0.0), 1.0)
    }

    public init(
        totalDiskBytes: Int64,
        availableDiskBytes: Int64,
        physicalMemoryBytes: UInt64,
        usedMemoryBytes: UInt64,
        memoryPressure: SystemMemoryPressureLevel
    ) {
        self.totalDiskBytes = totalDiskBytes
        self.availableDiskBytes = availableDiskBytes
        self.physicalMemoryBytes = physicalMemoryBytes
        self.usedMemoryBytes = usedMemoryBytes
        self.memoryPressure = memoryPressure
    }
}

/// 磁盘空间与内存压力采集器
public enum StorageAnalyzerService {
    public static func currentSnapshot(
        volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true)
    ) -> DiskAndMemorySnapshot {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        let values = try? volumeURL.resourceValues(forKeys: keys)
        let totalDisk = Int64(values?.volumeTotalCapacity ?? 0)
        let availableDisk: Int64
        if let important = values?.volumeAvailableCapacityForImportantUsage, important > 0 {
            availableDisk = important
        } else {
            availableDisk = Int64(values?.volumeAvailableCapacity ?? 0)
        }

        let physicalMem = ProcessInfo.processInfo.physicalMemory
        let (usedMem, pressure) = readMachMemoryUsage(physicalBytes: physicalMem)

        return DiskAndMemorySnapshot(
            totalDiskBytes: totalDisk,
            availableDiskBytes: min(max(0, availableDisk), max(0, totalDisk)),
            physicalMemoryBytes: physicalMem,
            usedMemoryBytes: usedMem,
            memoryPressure: pressure
        )
    }

    private static func readMachMemoryUsage(
        physicalBytes: UInt64
    ) -> (usedBytes: UInt64, pressure: SystemMemoryPressureLevel) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let kernResult = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard kernResult == KERN_SUCCESS, physicalBytes > 0 else {
            return (0, .normal)
        }

        let pageSize = UInt64(max(4096, Int(getpagesize())))
        let activeAndWiredPages = UInt64(stats.active_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        let usedBytes = min(physicalBytes, activeAndWiredPages * pageSize)
        let ratio = Double(usedBytes) / Double(physicalBytes)
        let compressedRatio = Double(UInt64(stats.compressor_page_count) * pageSize) / Double(physicalBytes)

        let pressure: SystemMemoryPressureLevel
        if ratio >= 0.88 || compressedRatio >= 0.28 {
            pressure = .critical
        } else if ratio >= 0.75 || compressedRatio >= 0.15 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        return (usedBytes, pressure)
    }
}

/// DMG 自动安装过程错误定义
public enum DMGInstallError: LocalizedError, Equatable, Sendable {
    case invalidDMGFile
    case mountFailed(String)
    case noApplicationFoundInVolume
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDMGFile:
            return "所选文件不是有效的 .dmg 磁盘镜像"
        case .mountFailed(let detail):
            return "挂载磁盘镜像失败：\(detail)"
        case .noApplicationFoundInVolume:
            return "镜像内未检测到可安装的 .app 应用程序包"
        case .copyFailed(let detail):
            return "拷入应用程序目录失败：\(detail)"
        }
    }
}

/// DMG 一键安装助手：自动挂载 `.dmg`、定位 `.app`、`ditto` 拷入 `/Applications`、清除隔离属性并推出镜像
@MainActor
public final class DMGAutoInstaller: ObservableObject {
    public static let shared = DMGAutoInstaller()

    public enum InstallStage: Equatable, Sendable {
        case idle
        case mounting(dmgName: String)
        case copying(appName: String)
        case cleaningQuarantine(appName: String)
        case detaching
        case completed(installedAppURL: URL)
        case failed(message: String)
    }

    @Published public private(set) var stage: InstallStage = .idle
    @Published public private(set) var statusMessage: String = "将 .dmg 安装包拖入此处，一键挂载并安装到「应用程序」"
    @Published public var moveSourceDMGToTrash: Bool = false

    public init() {}

    /// 解析 `hdiutil attach -nobrowse -plist` 返回的标准输出提取挂载点列表
    public nonisolated static func parseMountPoints(fromHdiutilPlistData data: Data) -> [URL] {
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            return []
        }

        var urls: [URL] = []
        for entity in entities {
            if let mountPath = entity["mount-point"] as? String, !mountPath.isEmpty {
                urls.append(URL(fileURLWithPath: mountPath, isDirectory: true))
            }
        }
        return urls
    }

    /// 执行全自动 DMG 安装流水线
    @discardableResult
    public func installDMG(
        at dmgURL: URL,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    ) async throws -> URL {
        guard dmgURL.pathExtension.lowercased() == "dmg",
              FileManager.default.fileExists(atPath: dmgURL.path) else {
            stage = .failed(message: DMGInstallError.invalidDMGFile.localizedDescription)
            statusMessage = DMGInstallError.invalidDMGFile.localizedDescription
            throw DMGInstallError.invalidDMGFile
        }

        let dmgName = dmgURL.lastPathComponent
        stage = .mounting(dmgName: dmgName)
        statusMessage = "正在挂载镜像 \(dmgName)…"

        let attachResult = await Self.runCommand(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", "-nobrowse", "-readonly", "-plist", dmgURL.path]
        )

        guard attachResult.exitCode == 0 else {
            let err = DMGInstallError.mountFailed(attachResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            stage = .failed(message: err.localizedDescription)
            statusMessage = err.localizedDescription
            throw err
        }

        let mountPoints = Self.parseMountPoints(fromHdiutilPlistData: attachResult.stdoutData)
        guard let mountURL = mountPoints.first else {
            let err = DMGInstallError.mountFailed("未解析到镜像挂载路径")
            stage = .failed(message: err.localizedDescription)
            statusMessage = err.localizedDescription
            throw err
        }

        do {
            guard let sourceAppURL = Self.locatePrimaryAppBundle(in: mountURL) else {
                throw DMGInstallError.noApplicationFoundInVolume
            }

            let appName = sourceAppURL.lastPathComponent
            let destinationAppURL = applicationsDirectory.appendingPathComponent(appName, isDirectory: true)

            stage = .copying(appName: appName)
            statusMessage = "正在将 \(appName) 拷入「应用程序」…"

            if FileManager.default.fileExists(atPath: destinationAppURL.path) {
                try? FileManager.default.trashItem(at: destinationAppURL, resultingItemURL: nil)
            }

            let dittoRes = await Self.runCommand(
                executable: "/usr/bin/ditto",
                arguments: [sourceAppURL.path, destinationAppURL.path]
            )
            guard dittoRes.exitCode == 0 else {
                throw DMGInstallError.copyFailed(dittoRes.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            stage = .cleaningQuarantine(appName: appName)
            statusMessage = "正在清除 \(appName) 隔离属性…"
            _ = await Self.runCommand(
                executable: "/usr/bin/xattr",
                arguments: ["-dr", "com.apple.quarantine", destinationAppURL.path]
            )

            stage = .detaching
            statusMessage = "正在安全推出安装镜像…"
            await Self.detachMountPoint(mountURL)

            if moveSourceDMGToTrash {
                try? FileManager.default.trashItem(at: dmgURL, resultingItemURL: nil)
            }

            stage = .completed(installedAppURL: destinationAppURL)
            statusMessage = "已完成安装：\(appName)"
            return destinationAppURL
        } catch {
            await Self.detachMountPoint(mountURL)
            stage = .failed(message: error.localizedDescription)
            statusMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - 后台子进程与镜像辅助

    private nonisolated static func locatePrimaryAppBundle(in mountURL: URL) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: mountURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for item in entries where item.pathExtension.lowercased() == "app" {
            let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if vals?.isSymbolicLink == true { continue }
            if vals?.isDirectory == true {
                return item
            }
        }
        return nil
    }

    private nonisolated static func detachMountPoint(_ mountURL: URL) async {
        let normal = await runCommand(
            executable: "/usr/bin/hdiutil",
            arguments: ["detach", mountURL.path]
        )
        if normal.exitCode != 0 {
            _ = await runCommand(
                executable: "/usr/bin/hdiutil",
                arguments: ["detach", mountURL.path, "-force"]
            )
        }
    }

    private nonisolated static func runCommand(
        executable: String,
        arguments: [String]
    ) async -> (exitCode: Int32, stdoutData: Data, stderr: String) {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return (
                    process.terminationStatus,
                    outData,
                    String(data: errData, encoding: .utf8) ?? ""
                )
            } catch {
                return (-1, Data(), error.localizedDescription)
            }
        }.value
    }
}
