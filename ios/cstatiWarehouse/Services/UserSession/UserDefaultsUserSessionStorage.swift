//
//  UserDefaultsUserSessionStorage.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

/// Профиль пользователя в UserDefaults. Токены не хранятся здесь — см. `PersistentUserSessionStorage` + Keychain.
final class UserDefaultsUserSessionStorage: UserSessionStorageProtocol {

    private enum Keys {
        static let user = "cstatiWarehouse.session.user"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentUser: User? {
        guard let data = defaults.data(forKey: Keys.user) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    var accessToken: String? { nil }

    var refreshToken: String? { nil }

    var isLoggedIn: Bool {
        false
    }

    func save(user: User, accessToken: String, refreshToken: String) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        }
    }

    func updateTokens(accessToken: String, refreshToken: String) {}

    func updateUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.user)
    }
}
