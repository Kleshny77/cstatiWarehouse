//
// ApiAuthService.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

final class ApiAuthService: AuthServiceProtocol {


    private let client: APIClient


    init(client: APIClient) {
        self.client = client
    }

    
    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        let body = LoginRequestDTO(email: request.email, password: request.password)
        client.request(
            path: "/auth/login",
            method: .post,
            body: body,
            authenticated: false
        ) { (result: Result<AuthResponseDTO, APIError>) in
            completion(Self.mapAuthResult(result))
        }
    }
    
    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
        let body = RegisterRequestDTO(
            name: request.name,
            lastName: request.lastName,
            email: request.email,
            password: request.password,
            avatarUrl: request.avatarURL?.absoluteString
        )
        client.request(
            path: "/auth/register",
            method: .post,
            body: body,
            authenticated: false
        ) { (result: Result<AuthResponseDTO, APIError>) in
            switch Self.mapAuthResult(result) {
            case .success(let login):
                completion(.success(RegisterResponse(
                    accessToken: login.accessToken,
                    refreshToken: login.refreshToken,
                    user: login.user
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        let body = TelegramRequestDTO(idToken: request.idToken)
        client.request(
            path: "/auth/telegram",
            method: .post,
            body: body,
            authenticated: false
        ) { (result: Result<AuthResponseDTO, APIError>) in
            completion(Self.mapAuthResult(result))
        }
    }

    func loginWithGoogle(request: GoogleLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        let body = GoogleAuthRequestDTO(idToken: request.idToken)
        client.request(
            path: "/auth/google",
            method: .post,
            body: body,
            authenticated: false
        ) { (result: Result<AuthResponseDTO, APIError>) in
            completion(Self.mapAuthResult(result))
        }
    }

    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void) {
        let avatarPayload: NullableString?
        switch request.avatarURL {
        case .some(.some(let url)):
            avatarPayload = .value(url.absoluteString)
        case .some(.none):
            avatarPayload = .null
        case .none:
            avatarPayload = nil
        }

        let body = UpdateProfileRequestDTO(name: request.name, lastName: request.lastName, avatarUrl: avatarPayload)
        client.request(
            path: "/auth/me",
            method: .patch,
            body: body,
            authenticated: true
        ) { (result: Result<AuthUserDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(Self.mapUser(dto)))
            case .failure(let error):
                completion(.failure(Self.mapAuthError(error)))
            }
        }
    }


    private static func mapAuthResult(_ result: Result<AuthResponseDTO, APIError>) -> Result<LoginResponse, AuthError> {
        switch result {
        case .success(let dto):
            return .success(LoginResponse(
                accessToken: dto.accessToken,
                refreshToken: dto.refreshToken,
                user: mapUser(dto.user)
            ))
        case .failure(let error):
            return .failure(mapAuthError(error))
        }
    }

    private static func mapUser(_ dto: AuthUserDTO) -> UserDTO {
        let avatar = dto.avatarUrl.flatMap { URL(string: $0) }
        return UserDTO(id: dto.id, name: dto.name, lastName: dto.lastName, email: dto.email, avatarURL: avatar)
    }

    private static func mapAuthError(_ error: APIError) -> AuthError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message, _):
            switch code {
            case "invalid_credentials":
                return .invalidCredentials
            case "email_taken":
                return .emailAlreadyTaken
            case "validation_error":
                return .validationError(message ?? "Некорректные данные")
            case "telegram_disabled":
                return .serverError(message ?? "Вход через Telegram недоступен")
            case "google_disabled":
                return .serverError(message ?? "Вход через Google недоступен на сервере")
            default:
                if status == 401 {
                    return .invalidCredentials
                }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}


private struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

private struct RegisterRequestDTO: Encodable {
    let name: String
    let lastName: String
    let email: String
    let password: String
    let avatarUrl: String?
}

private struct TelegramRequestDTO: Encodable {
    let idToken: String
}

private struct GoogleAuthRequestDTO: Encodable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

private enum NullableString: Encodable {
    case value(String)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

private struct UpdateProfileRequestDTO: Encodable {
    let name: String?
    let lastName: String?
    let avatarUrl: NullableString?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        if let name = name {
            try container.encode(name, forKey: .name)
        }
        if let lastName = lastName {
            try container.encode(lastName, forKey: .lastName)
        }
        if let avatarUrl = avatarUrl {
            try container.encode(avatarUrl, forKey: .avatarUrl)
        }
    }
}

private enum DynamicCodingKey: String, CodingKey {
    case name
    case lastName
    case avatarUrl
}

private struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO
}

private struct AuthUserDTO: Decodable {
    let id: String
    let name: String
    let lastName: String
    let email: String
    let avatarUrl: String?
}
