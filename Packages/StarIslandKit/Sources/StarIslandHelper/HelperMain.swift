import Darwin
import Foundation
import HardwareCleanKit
import IOKit
import IOKit.ps
import IslandCore
import ObjectiveC
import Security

private enum AppleSMCBridge {
    private static let kernelIndexSMC: UInt32 = 2
    private static let cmdReadKeyInfo: UInt8 = 9
    private static let cmdReadBytes: UInt8 = 5
    private static let cmdWriteBytes: UInt8 = 6

    struct SMCKeyData {
        struct Vers {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }
        struct PLimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }
        struct KeyInfo {
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        var key: UInt32 = 0
        var vers = Vers()
        var pLimitData = PLimitData()
        var keyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    static func fourCC(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for scalar in key.utf8.prefix(4) {
            result = (result << 8) | UInt32(scalar)
        }
        return result
    }

    static func withConnection<T>(_ body: (io_connect_t) -> T?) -> T? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
            return nil
        }
        defer { IOServiceClose(conn) }
        return body(conn)
    }

    private static func call(_ conn: io_connect_t, input: inout SMCKeyData, output: inout SMCKeyData) -> Bool {
        var outSize = MemoryLayout<SMCKeyData>.stride
        let kr = IOConnectCallStructMethod(
            conn,
            kernelIndexSMC,
            &input,
            MemoryLayout<SMCKeyData>.stride,
            &output,
            &outSize
        )
        return kr == kIOReturnSuccess && output.result == 0
    }

    static func readFloatKey(_ key: String) -> Float? {
        withConnection { conn in
            var req = SMCKeyData()
            var infoOut = SMCKeyData()
            req.key = fourCC(key)
            req.data8 = cmdReadKeyInfo
            guard call(conn, input: &req, output: &infoOut), infoOut.keyInfo.dataSize == 4 else {
                return nil
            }
            var readReq = SMCKeyData()
            var readOut = SMCKeyData()
            readReq.key = req.key
            readReq.keyInfo.dataSize = infoOut.keyInfo.dataSize
            readReq.data8 = cmdReadBytes
            guard call(conn, input: &readReq, output: &readOut) else {
                return nil
            }
            var value: Float = 0
            withUnsafeMutableBytes(of: &value) { dst in
                withUnsafeBytes(of: &readOut.bytes) { src in
                    dst.copyBytes(from: src.prefix(4))
                }
            }
            return value.isFinite ? value : nil
        }
    }

    static func writeBytesKey(_ key: String, bytes: [UInt8]) -> Bool {
        withConnection { conn in
            var req = SMCKeyData()
            var infoOut = SMCKeyData()
            req.key = fourCC(key)
            req.data8 = cmdReadKeyInfo
            guard call(conn, input: &req, output: &infoOut),
                  infoOut.keyInfo.dataSize > 0,
                  Int(infoOut.keyInfo.dataSize) <= 32 else {
                return false
            }

            var writeReq = SMCKeyData()
            var writeOut = SMCKeyData()
            writeReq.key = req.key
            writeReq.data8 = cmdWriteBytes
            writeReq.keyInfo.dataSize = infoOut.keyInfo.dataSize
            withUnsafeMutableBytes(of: &writeReq.bytes) { dst in
                for (i, byte) in bytes.prefix(Int(infoOut.keyInfo.dataSize)).enumerated() {
                    dst[i] = byte
                }
            }
            return call(conn, input: &writeReq, output: &writeOut)
        } ?? false
    }

    static func readHardwareSnapshot() -> BatteryHardwareSnapshot {
        var percentage = 100
        var isCharging = false
        var isPluggedIn = true
        var temperatureC = 32.0
        var cycleCount = 0

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
           let first = list.first,
           let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] {
            if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                percentage = max(0, min(100, Int(round(Double(cur) * 100.0 / Double(maxCap)))))
            }
            if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                isCharging = charging
            }
            if let powerState = desc[kIOPSPowerSourceStateKey as String] as? String {
                isPluggedIn = (powerState == (kIOPSACPowerValue as String))
            }
        }

        let batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if batteryService != 0 {
            defer { IOObjectRelease(batteryService) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(batteryService, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsRef?.takeRetainedValue() as? [String: Any] {
                if let cycles = props["CycleCount"] as? Int {
                    cycleCount = cycles
                }
                if let rawTemp = props["Temperature"] as? Int, rawTemp > 0 {
                    if rawTemp > 25000 {
                        temperatureC = Double(rawTemp) / 100.0 - 273.15
                    } else {
                        temperatureC = Double(rawTemp) / 100.0
                    }
                }
            }
        }

        let currentRPM = Int((readFloatKey("F0Ac") ?? 0).rounded())
        let minRPM = max(800, Int((readFloatKey("F0Mn") ?? 1200).rounded()))
        let maxRPM = max(minRPM + 1000, Int((readFloatKey("F0Mx") ?? 5500).rounded()))

        return BatteryHardwareSnapshot(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            temperatureCelsius: temperatureC,
            cycleCount: cycleCount,
            currentFanRPM: max(0, currentRPM),
            minFanRPM: minRPM,
            maxFanRPM: maxRPM
        )
    }
}

final class StarIslandHelperService: NSObject, NSXPCListenerDelegate, StarIslandHelperXPCProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard let token = Self.extractAuditToken(from: newConnection),
              CodesignValidator.validateClient(auditToken: token) else {
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: StarIslandHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func pingProtocolVersion(withReply reply: @escaping (Int) -> Void) {
        reply(StarIslandHelperConstants.protocolVersion)
    }

    func fetchHardwareSnapshotJSON(withReply reply: @escaping (Data?) -> Void) {
        let snapshot = AppleSMCBridge.readHardwareSnapshot()
        reply(try? JSONEncoder().encode(snapshot))
    }

    func setChargeControl(inhibit: Bool, limit: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        let clampedLimit = UInt8(max(50, min(100, limit)))
        let inhibitByte: UInt8 = inhibit ? 0x02 : 0x00
        let chteBytes: [UInt8] = inhibit ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00]

        let wroteAppleSilicon = AppleSMCBridge.writeBytesKey("CH0B", bytes: [inhibitByte])
            || AppleSMCBridge.writeBytesKey("CH0C", bytes: [inhibitByte])
            || AppleSMCBridge.writeBytesKey("CHTE", bytes: chteBytes)
        let wroteBCLM = AppleSMCBridge.writeBytesKey("BCLM", bytes: [clampedLimit])

        if wroteAppleSilicon || wroteBCLM {
            reply(true, nil)
        } else {
            reply(false, "当前机型固件未开放 SMC 充电寄存器写入（桌面 Mac 或受固件保护）")
        }
    }

    func setFanTarget(manual: Bool, rpm: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        if !manual {
            let ok = AppleSMCBridge.writeBytesKey("F0Md", bytes: [0x00])
            reply(ok, ok ? nil : "当前设备未检测到可控风扇通道")
            return
        }
        var target = Float(max(800, min(7000, rpm)))
        let floatBytes = withUnsafeBytes(of: &target) { Array($0) }
        let modeOK = AppleSMCBridge.writeBytesKey("F0Md", bytes: [0x01])
        let targetOK = AppleSMCBridge.writeBytesKey("F0Tg", bytes: floatBytes)
        if modeOK && targetOK {
            reply(true, nil)
        } else {
            reply(false, "当前设备未开放手动风扇转速寄存器")
        }
    }

    func updateManagedHosts(domains: [String], withReply reply: @escaping (Bool, String?) -> Void) {
        let hostsURL = URL(fileURLWithPath: "/etc/hosts")
        do {
            let existing = (try? String(contentsOf: hostsURL, encoding: .utf8)) ?? "127.0.0.1\tlocalhost\n::1\tlocalhost\n"
            let updated = domains.isEmpty
                ? HostsBlocklistRenderer.removeManagedBlock(from: existing)
                : HostsBlocklistRenderer.applyBlockDomains(domains, to: existing)
            try updated.write(to: hostsURL, atomically: true, encoding: .utf8)
            let flush = Process()
            flush.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            flush.arguments = ["-flushcache"]
            try? flush.run()
            flush.waitUntilExit()
            reply(true, nil)
        } catch {
            reply(false, "写入 /etc/hosts 失败：\(error.localizedDescription)")
        }
    }

    func installAppBundle(stagedPath: String, destinationPath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        let rawDestURL = URL(fileURLWithPath: destinationPath)
        let canonicalParent = rawDestURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let canonicalDestURL = canonicalParent.appendingPathComponent(rawDestURL.lastPathComponent)

        guard canonicalDestURL.path == "/Applications/StarIsland.app" else {
            reply(false, "拒绝安装：目标路径必须严格位于 /Applications/StarIsland.app")
            return
        }

        // Ad-hoc 本地构建无唯一开发者团队证书锚点，禁止通过 root 守护进程免密覆盖，交由主程序回退管理员授权弹窗
        guard let helperTeamID = CodesignValidator.currentExecutableTeamIdentifier(),
              !helperTeamID.isEmpty else {
            reply(false, "本地 Ad-hoc 构建需通过系统管理员授权完成覆盖升级")
            return
        }

        let stagedURL = URL(fileURLWithPath: stagedPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: stagedURL.path) else {
            reply(false, "暂存更新包不存在")
            return
        }

        let rootSupportDir = URL(fileURLWithPath: "/Library/Application Support/StarIsland", isDirectory: true)
        let rootStageDir = rootSupportDir.appendingPathComponent(".root-update-\(UUID().uuidString)", isDirectory: true)
        let isolatedAppURL = rootStageDir.appendingPathComponent("StarIsland.app", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootStageDir)
        }

        do {
            try FileManager.default.createDirectory(
                at: rootStageDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootStageDir.path)

            // 先将候选包拷入 0700 root 专属隔离目录，彻底消除校验后被替换的 TOCTOU 竞态窗口
            let copyIntoRoot = Process()
            copyIntoRoot.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            copyIntoRoot.arguments = [stagedURL.path, isolatedAppURL.path]
            try copyIntoRoot.run()
            copyIntoRoot.waitUntilExit()
            guard copyIntoRoot.terminationStatus == 0 else {
                reply(false, "复制到受保护暂存目录失败（返回码 \(copyIntoRoot.terminationStatus)）")
                return
            }

            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-cr", isolatedAppURL.path]
            try? xattr.run()
            xattr.waitUntilExit()

            var staticCode: SecStaticCode?
            let strictFlags = SecCSFlags(
                rawValue: UInt32(kSecCSStrictValidate | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures)
            )
            guard SecStaticCodeCreateWithPath(isolatedAppURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
                  let code = staticCode,
                  SecStaticCodeCheckValidity(code, strictFlags, nil) == errSecSuccess else {
                reply(false, "暂存更新包严格签名与嵌套组件校验未通过")
                return
            }

            var infoRef: CFDictionary?
            guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)), &infoRef) == errSecSuccess,
                  let info = infoRef as? [String: Any],
                  (info[kSecCodeInfoIdentifier as String] as? String) == StarIslandHelperConstants.appBundleIdentifier,
                  (info[kSecCodeInfoTeamIdentifier as String] as? String) == helperTeamID else {
                reply(false, "暂存更新包应用标识符或开发者团队 ID 不匹配")
                return
            }

            if FileManager.default.fileExists(atPath: canonicalDestURL.path) {
                try FileManager.default.removeItem(at: canonicalDestURL)
            }
            let installDitto = Process()
            installDitto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            installDitto.arguments = [isolatedAppURL.path, canonicalDestURL.path]
            try installDitto.run()
            installDitto.waitUntilExit()
            guard installDitto.terminationStatus == 0 else {
                reply(false, "ditto 复制返回码 \(installDitto.terminationStatus)")
                return
            }
            reply(true, nil)
        } catch {
            reply(false, "替换应用失败：\(error.localizedDescription)")
        }
    }

    private static func extractAuditToken(from connection: NSXPCConnection) -> audit_token_t? {
        let sel = NSSelectorFromString("auditToken")
        guard connection.responds(to: sel),
              let method = class_getInstanceMethod(type(of: connection), sel) else {
            return nil
        }
        typealias Getter = @convention(c) (AnyObject, Selector) -> audit_token_t
        let fn = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        return fn(connection, sel)
    }
}

@main
enum StarIslandHelperMain {
    static func main() {
        let delegate = StarIslandHelperService()
        let listener = NSXPCListener(machServiceName: StarIslandHelperConstants.machServiceName)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}
