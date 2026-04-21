//
//  APIError.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// Унифицированные ошибки сетевого слоя. Доменные сервисы маппят их в свои типы.
enum APIError: Error {
    case transport(underlying: Error)
    case decoding(underlying: Error)
    /// HTTP-ошибка 4xx/5xx. Если бэкенд вернул `{ "error": ..., "message": ... }`, поля заполнены.
    case server(status: Int, code: String?, message: String?)
    /// 401 после неуспешного рефреша — сессия очищена, нужно идти на логин.
    case unauthorized
}

/// Формат ошибки из writeError бэкенда: `{ "error": "code", "message": "..." }`.
/// Явный `nonisolated init(from:)` нужен для Swift 6: иначе синтезированный `Decodable`
/// может считаться изолированным на MainActor, а декодирование в `URLSession` идёт вне актора.
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
