//
//  UserSessionStorageProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol UserSessionStorageProtocol: AnyObject {
    var currentUser: User? { get }
    var accessToken: String? { get }
    var refreshToken: String? { get }
    var isLoggedIn: Bool { get }

    func save(user: User, accessToken: String, refreshToken: String)
    func updateTokens(accessToken: String, refreshToken: String)
    func updateUser(_ user: User)
    func clear()
}
