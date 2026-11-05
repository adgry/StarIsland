import Foundation

public protocol AIQueryServiceProtocol: AnyObject, Sendable {
    func ask(prompt: String, imagePNGData: Data?) async throws -> String
    func translate(text: String, targetLanguage: String) async throws -> String
}

public struct BatteryHardwareSnapshot: Codable, Equatable, Sendable {
    public var percentage: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var temperatureCelsius: Double
    public var cycleCount: Int
    public var currentFanRPM: Int
    public var minFanRPM: Int
    public var maxFanRPM: Int

    public init(
        percentage: Int = 100,
        isCharging: Bool = false,
        isPluggedIn: Bool = true,
        temperatureCelsius: Double = 32.0,
        cycleCount: Int = 0,
        currentFanRPM: Int = 0,
        minFanRPM: Int = 1200,
        maxFanRPM: Int = 5500
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.temperatureCelsius = temperatureCelsius
        self.cycleCount = cycleCount
        self.currentFanRPM = currentFanRPM
        self.minFanRPM = minFanRPM
        self.maxFanRPM = maxFanRPM
    }
}

public protocol PrivilegedHelperProtocol: AnyObject, Sendable {
    func ping() async -> Bool
    func readHardwareSnapshot() async -> BatteryHardwareSnapshot?
    func setChargeInhibit(_ inhibit: Bool, chargeLimit: Int) async -> Bool
    func setFanControl(manual: Bool, targetRPM: Int) async -> Bool
    func applyManagedBlockedDomains(_ domains: [String]) async -> Bool
    func installStagedUpdate(from stagedAppPath: String, to targetAppPath: String) async throws -> Bool
}

@objc public protocol StarIslandHelperXPCProtocol {
    func pingProtocolVersion(withReply reply: @escaping (Int) -> Void)
    func fetchHardwareSnapshotJSON(withReply reply: @escaping (Data?) -> Void)
    func setChargeControl(inhibit: Bool, limit: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func setFanTarget(manual: Bool, rpm: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func updateManagedHosts(domains: [String], withReply reply: @escaping (Bool, String?) -> Void)
    func installAppBundle(stagedPath: String, destinationPath: String, withReply reply: @escaping (Bool, String?) -> Void)
}

public enum StarIslandHelperConstants {
    public static let machServiceName = "com.adgry.starisland.helper"
    public static let appBundleIdentifier = "com.adgry.starisland"
    public static let plistName = "com.adgry.starisland.helper.plist"
    public static let protocolVersion: Int = 1
}

@MainActor
public final class ServiceRegistry {
    public static let shared = ServiceRegistry()

    public var aiService: AIQueryServiceProtocol?
    public var helperService: PrivilegedHelperProtocol?
    public var onOpenSettingsSection: ((SettingSection) -> Void)?

    private init() {}
}
