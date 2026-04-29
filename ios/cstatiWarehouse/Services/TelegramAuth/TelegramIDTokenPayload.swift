//
//  TelegramIDTokenPayload.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

struct TelegramIDTokenPayload: Decodable, Equatable {
    let sub: String
    let name: String?
    let preferredUsername: String?
    let phoneNumber: String?
    let email: String?
    let pictureURL: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case name
        case preferredUsername = "preferred_username"
        case phoneNumber = "phone_number"
        case email
        case pictureURL = "picture"
    }
    
    static func decode(idToken: String) -> TelegramIDTokenPayload? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        guard let payloadData = base64urlDecode(String(parts[1])) else { return nil }
        return try? JSONDecoder().decode(TelegramIDTokenPayload.self, from: payloadData)
    }
    
    private static func base64urlDecode(_ string: String) -> Data? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let mod = padded.count % 4
        if mod != 0 {
            padded.append(String(repeating: "=", count: 4 - mod))
        }
        return Data(base64Encoded: padded)
    }
}
