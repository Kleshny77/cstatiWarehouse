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
struct APIServerErrorBody: Decodable {
    let error: String?
    let message: String?
}
