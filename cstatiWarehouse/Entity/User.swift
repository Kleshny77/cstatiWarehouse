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
    var avatarURL: URL?

    init(id: String? = nil, email: String, name: String, avatarURL: URL? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
    }
}
