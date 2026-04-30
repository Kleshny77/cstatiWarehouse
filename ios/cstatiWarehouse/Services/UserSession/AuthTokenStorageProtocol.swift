//
//  AuthTokenStorageProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol AuthTokenStorageProtocol: AnyObject {
    var accessToken: String? { get }
    var refreshToken: String? { get }

    func save(accessToken: String, refreshToken: String)
    func updateTokens(accessToken: String, refreshToken: String)
    func clear()
}
