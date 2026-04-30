//
//  PersistentUserSessionStorageTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Testing
@testable import cstatiWarehouse
import Foundation

@Suite("PersistentUserSessionStorage")
@MainActor
struct PersistentUserSessionStorageTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "cstatiWarehouse.tests.session.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test
    func isLoggedIn_isFalseByDefault() {
        let defaults = makeIsolatedDefaults()
        let tokens = MockAuthTokenStorage()
        let storage = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)

        #expect(storage.isLoggedIn == false)
        #expect(storage.currentUser == nil)
        #expect(storage.accessToken == nil)
        #expect(storage.refreshToken == nil)
    }

    @Test
    func save_persistsUserAndTokens() {
        let defaults = makeIsolatedDefaults()
        let tokens = MockAuthTokenStorage()
        let storage = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)
        let user = User(email: "kot@mail.ru", name: "Кот")

        storage.save(user: user, accessToken: "abc-123", refreshToken: "r-1")

        #expect(storage.isLoggedIn == true)
        #expect(storage.currentUser == user)
        #expect(storage.accessToken == "abc-123")
        #expect(storage.refreshToken == "r-1")
        #expect(tokens.savedAccess == "abc-123")
        #expect(tokens.savedRefresh == "r-1")
    }

    @Test
    func clear_wipesUserAndTokens() {
        let defaults = makeIsolatedDefaults()
        let tokens = MockAuthTokenStorage()
        let storage = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)
        storage.save(user: User(email: "a@b.c", name: "A"), accessToken: "t", refreshToken: "r")

        storage.clear()

        #expect(storage.isLoggedIn == false)
        #expect(storage.currentUser == nil)
        #expect(storage.accessToken == nil)
        #expect(storage.refreshToken == nil)
        #expect(tokens.savedAccess == nil)
        #expect(tokens.savedRefresh == nil)
    }

    @Test
    func updateUser_replacesStoredUser_withoutTouchingTokens() {
        let defaults = makeIsolatedDefaults()
        let tokens = MockAuthTokenStorage()
        let storage = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)
        storage.save(
            user: User(id: "1", email: "a@b.c", name: "A", avatarURL: nil),
            accessToken: "tok",
            refreshToken: "r"
        )

        let updated = User(
            id: "1",
            email: "a@b.c",
            name: "B",
            avatarURL: URL(string: "https://cdn.example.com/a.png")
        )
        storage.updateUser(updated)

        #expect(storage.currentUser?.name == "B")
        #expect(storage.currentUser?.avatarURL?.absoluteString == "https://cdn.example.com/a.png")
        #expect(storage.accessToken == "tok")
        #expect(storage.refreshToken == "r")
    }

    @Test
    func separateInstances_shareSameDefaultsAndTokens() {
        let defaults = makeIsolatedDefaults()
        let tokens = MockAuthTokenStorage()
        let writer = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)
        writer.save(user: User(email: "x@y.z", name: "X"), accessToken: "tok", refreshToken: "r")

        let reader = PersistentUserSessionStorage(defaults: defaults, tokenStorage: tokens)

        #expect(reader.isLoggedIn == true)
        #expect(reader.currentUser?.email == "x@y.z")
        #expect(reader.accessToken == "tok")
    }
}

private final class MockAuthTokenStorage: AuthTokenStorageProtocol {

    private(set) var savedAccess: String?
    private(set) var savedRefresh: String?

    var accessToken: String? { savedAccess }
    var refreshToken: String? { savedRefresh }

    func save(accessToken: String, refreshToken: String) {
        savedAccess = accessToken
        savedRefresh = refreshToken
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func clear() {
        savedAccess = nil
        savedRefresh = nil
    }
}
