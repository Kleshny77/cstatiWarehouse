//
//  User.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

struct User: Codable, Equatable {
    let id: String?
    let email: String
    var name: String
    var lastName: String
    var avatarURL: URL?

    init(id: String? = nil, email: String, name: String, lastName: String = "", avatarURL: URL? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.lastName = lastName
        self.avatarURL = avatarURL
    }

    var fullName: String {
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fn = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ln.isEmpty ? fn : fn + " " + ln
    }
}
