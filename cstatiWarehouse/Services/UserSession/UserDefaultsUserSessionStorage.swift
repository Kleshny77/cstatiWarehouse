//
//  UserDefaultsUserSessionStorage.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

final class UserDefaultsUserSessionStorage: UserSessionStorageProtocol {

    // MARK: Properties

    private enum Keys {
        static let user = "cstatiWarehouse.session.user"
        static let accessToken = "cstatiWarehouse.session.accessToken"
        static let refreshToken = "cstatiWarehouse.session.refreshToken"
    }

    private let defaults: UserDefaults

    // MARK: Lifecycle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Public Methods

    var currentUser: User? {
        guard let data = defaults.data(forKey: Keys.user) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    var accessToken: String? {
        defaults.string(forKey: Keys.accessToken)
    }

    var refreshToken: String? {
        defaults.string(forKey: Keys.refreshToken)
    }

    var isLoggedIn: Bool {
        accessToken != nil && currentUser != nil
    }

    func save(user: User, accessToken: String, refreshToken: String) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        }
        defaults.set(accessToken, forKey: Keys.accessToken)
        defaults.set(refreshToken, forKey: Keys.refreshToken)
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        defaults.set(accessToken, forKey: Keys.accessToken)
        defaults.set(refreshToken, forKey: Keys.refreshToken)
    }

    func updateUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.user)
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
    }
}
