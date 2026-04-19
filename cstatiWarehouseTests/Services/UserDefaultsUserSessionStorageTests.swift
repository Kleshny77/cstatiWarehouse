//
//  UserDefaultsUserSessionStorageTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Testing
@testable import cstatiWarehouse
import Foundation

@Suite("UserDefaultsUserSessionStorage")
struct UserDefaultsUserSessionStorageTests {
    
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "cstatiWarehouse.tests.session.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }
    
    @Test
    func isLoggedIn_isFalseByDefault() {
        let defaults = makeIsolatedDefaults()
        let storage = UserDefaultsUserSessionStorage(defaults: defaults)
        
        #expect(storage.isLoggedIn == false)
        #expect(storage.currentUser == nil)
        #expect(storage.accessToken == nil)
        #expect(storage.refreshToken == nil)
    }
    
    @Test
    func save_persistsUserAndTokens() {
        let defaults = makeIsolatedDefaults()
        let storage = UserDefaultsUserSessionStorage(defaults: defaults)
        let user = User(email: "kot@mail.ru", name: "Кот")
        
        storage.save(user: user, accessToken: "abc-123", refreshToken: "r-1")
        
        #expect(storage.isLoggedIn == true)
        #expect(storage.currentUser == user)
        #expect(storage.accessToken == "abc-123")
        #expect(storage.refreshToken == "r-1")
    }
    
    @Test
    func clear_wipesUserAndTokens() {
        let defaults = makeIsolatedDefaults()
        let storage = UserDefaultsUserSessionStorage(defaults: defaults)
        storage.save(user: User(email: "a@b.c", name: "A"), accessToken: "t", refreshToken: "r")
        
        storage.clear()
        
        #expect(storage.isLoggedIn == false)
        #expect(storage.currentUser == nil)
        #expect(storage.accessToken == nil)
        #expect(storage.refreshToken == nil)
    }
    
    @Test
    func updateUser_replacesStoredUser_withoutTouchingTokens() {
        let defaults = makeIsolatedDefaults()
        let storage = UserDefaultsUserSessionStorage(defaults: defaults)
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
    func separateInstances_shareSameDefaults() {
        let defaults = makeIsolatedDefaults()
        let writer = UserDefaultsUserSessionStorage(defaults: defaults)
        writer.save(user: User(email: "x@y.z", name: "X"), accessToken: "tok", refreshToken: "r")
        
        let reader = UserDefaultsUserSessionStorage(defaults: defaults)
        
        #expect(reader.isLoggedIn == true)
        #expect(reader.currentUser?.email == "x@y.z")
    }
}
