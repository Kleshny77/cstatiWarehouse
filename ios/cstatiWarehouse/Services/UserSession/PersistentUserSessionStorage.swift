//
//  PersistentUserSessionStorage.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

/// Хранит профиль в UserDefaults, токены — в Keychain. При первом обращении переносит токены из старых ключей UserDefaults.
final class PersistentUserSessionStorage: UserSessionStorageProtocol {

    private enum LegacyKeys {
        static let accessToken = "cstatiWarehouse.session.accessToken"
        static let refreshToken = "cstatiWarehouse.session.refreshToken"
    }

    private let profileStorage: UserDefaultsUserSessionStorage
    private let tokenStorage: AuthTokenStorageProtocol
    private let defaults: UserDefaults
    private var didMigrateLegacyTokens = false

    init(
        defaults: UserDefaults = .standard,
        tokenStorage: AuthTokenStorageProtocol = KeychainAuthTokenStorage()
    ) {
        self.defaults = defaults
        self.profileStorage = UserDefaultsUserSessionStorage(defaults: defaults)
        self.tokenStorage = tokenStorage
    }

    var currentUser: User? { profileStorage.currentUser }

    var accessToken: String? {
        migrateLegacyTokensIfNeeded()
        return tokenStorage.accessToken
    }

    var refreshToken: String? {
        migrateLegacyTokensIfNeeded()
        return tokenStorage.refreshToken
    }

    var isLoggedIn: Bool {
        accessToken != nil && currentUser != nil
    }

    func save(user: User, accessToken: String, refreshToken: String) {
        profileStorage.save(user: user, accessToken: accessToken, refreshToken: refreshToken)
        tokenStorage.save(accessToken: accessToken, refreshToken: refreshToken)
        removeLegacyTokenKeys()
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        profileStorage.updateTokens(accessToken: accessToken, refreshToken: refreshToken)
        tokenStorage.updateTokens(accessToken: accessToken, refreshToken: refreshToken)
        removeLegacyTokenKeys()
    }

    func updateUser(_ user: User) {
        profileStorage.updateUser(user)
    }

    func clear() {
        profileStorage.clear()
        tokenStorage.clear()
        removeLegacyTokenKeys()
    }

    private func migrateLegacyTokensIfNeeded() {
        guard !didMigrateLegacyTokens else { return }
        didMigrateLegacyTokens = true
        guard tokenStorage.accessToken == nil,
              tokenStorage.refreshToken == nil,
              let legacyAccess = defaults.string(forKey: LegacyKeys.accessToken),
              let legacyRefresh = defaults.string(forKey: LegacyKeys.refreshToken) else { return }
        tokenStorage.save(accessToken: legacyAccess, refreshToken: legacyRefresh)
        removeLegacyTokenKeys()
    }

    private func removeLegacyTokenKeys() {
        defaults.removeObject(forKey: LegacyKeys.accessToken)
        defaults.removeObject(forKey: LegacyKeys.refreshToken)
    }
}
