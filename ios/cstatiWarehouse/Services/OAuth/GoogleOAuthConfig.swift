//
//  GoogleOAuthConfig.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum GoogleOAuthConfig {

    /// Client ID: сначала `GoogleService-Info.plist` (как в консоли Google), иначе `GIDClientID` в Info.plist.
    static var clientID: String {
        if let fromPlist = clientIDFromGoogleServiceInfo(), !fromPlist.isEmpty {
            return fromPlist
        }
        return (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool {
        !clientID.isEmpty
    }

    private static func clientIDFromGoogleServiceInfo() -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let raw = dict["CLIENT_ID"] as? String else {
            return nil
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
