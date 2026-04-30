//
//  KeychainAuthTokenStorage.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Security

final class KeychainAuthTokenStorage: AuthTokenStorageProtocol {

    private enum Keys {
        static let access = "cstatiWarehouse.keychain.accessToken"
        static let refresh = "cstatiWarehouse.keychain.refreshToken"
    }

    private let service = "cstatiWarehouse.auth.tokens"

    var accessToken: String? {
        KeychainHelper.readString(service: service, account: Keys.access)
    }

    var refreshToken: String? {
        KeychainHelper.readString(service: service, account: Keys.refresh)
    }

    func save(accessToken: String, refreshToken: String) {
        KeychainHelper.writeString(accessToken, service: service, account: Keys.access)
        KeychainHelper.writeString(refreshToken, service: service, account: Keys.refresh)
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func clear() {
        KeychainHelper.delete(service: service, account: Keys.access)
        KeychainHelper.delete(service: service, account: Keys.refresh)
    }
}

enum KeychainHelper {

    static func writeString(_ value: String, service: String, account: String) {
        delete(service: service, account: account)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func readString(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
