//
//  AppSecurity.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import Foundation

struct AppCodeSignatureIdentity: Equatable {
    let signingIdentifier: String
    let teamIdentifier: String?
    let bundleIdentifier: String
}

enum AppSecurityValidationError: LocalizedError {
    case notAnApplication
    case bundleIdentifierMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .notAnApplication:
            "下载的项目不是有效的应用程序包。"
        case .bundleIdentifierMismatch(let expected, let actual):
            "此更新适用于 \(actual)，而非 \(expected)。"
        }
    }
}

enum AppSecurityValidator {
    static func identity(at bundleURL: URL, requireValidSignature: Bool = true) throws -> AppCodeSignatureIdentity {
        guard bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier else {
            throw AppSecurityValidationError.notAnApplication
        }
        return AppCodeSignatureIdentity(
            signingIdentifier: bundleIdentifier,
            teamIdentifier: nil,
            bundleIdentifier: bundleIdentifier
        )
    }

    static func validateReplacement(candidate: URL, replacing installed: URL) throws {
        let candidateID = try identity(at: candidate).bundleIdentifier
        let installedID = try identity(at: installed).bundleIdentifier
        guard candidateID == installedID else {
            throw AppSecurityValidationError.bundleIdentifierMismatch(expected: installedID, actual: candidateID)
        }
    }

    static func applicationGroups(at bundleURL: URL) -> Set<String> { [] }

    static func isSafeIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty,
              identifier != ".",
              !identifier.contains("..") else {
            return false
        }
        return identifier.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar == "."
                || scalar == "-"
                || scalar == "_"
        }
    }
}
#endif