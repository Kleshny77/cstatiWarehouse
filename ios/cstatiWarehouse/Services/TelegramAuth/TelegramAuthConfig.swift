//
//  TelegramAuthConfig.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

enum TelegramAuthConfig {

    static let clientId: String = "8294359177"

    static let redirectUri: String = ""

    static let fallbackScheme: String? = nil

    static let scopes: [String] = ["profile", "phone"]

    static var isConfigured: Bool {
        guard !clientId.isEmpty else { return false }
        guard let url = URL(string: redirectUri),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host,
              !host.isEmpty
        else { return false }
        return true
    }
}
