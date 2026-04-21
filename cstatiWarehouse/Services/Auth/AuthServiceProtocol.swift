//
// AuthServiceProtocol.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

enum AuthError: Error {
    case invalidCredentials
    case emailAlreadyTaken
    case validationError(String)
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .invalidCredentials:
            return "Неверный email или пароль"
        case .emailAlreadyTaken:
            return "Этот email уже зарегистрирован"
        case .validationError(let text):
            return text
        case .networkError:
            return "Ошибка сети. Проверьте подключение."
        case .serverError(let text):
            return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        }
    }
}

struct LoginRequest {
    let email: String
    let password: String
}

struct LoginResponse {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

struct RegisterRequest {
    let name: String
    let lastName: String
    let email: String
    let password: String
    let avatarURL: URL?
}

struct RegisterResponse {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

struct TelegramLoginRequest {
    let idToken: String
}

struct UpdateProfileRequest {
    /// nil — не менять имя.
    let name: String?
    let lastName: String?
    /// nil — не менять аватар. URL без значения означает "сбросить".
    let avatarURL: URL??
}

struct UserDTO {
    let id: String
    let name: String
    let lastName: String
    let email: String
    let avatarURL: URL?
}

protocol AuthServiceProtocol: AnyObject {
    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void)
    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void)
    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void)
    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void)
}
