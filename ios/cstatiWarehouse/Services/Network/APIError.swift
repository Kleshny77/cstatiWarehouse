//
//  APIError.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

enum APIError: Error {
    case transport(underlying: Error)
    case decoding(underlying: Error)
    case server(status: Int, code: String?, message: String?, responseBody: Data?)
    case unauthorized
}

struct APIServerErrorBody: Decodable, Sendable {
    let error: String?
    let message: String?

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case message
    }
}
