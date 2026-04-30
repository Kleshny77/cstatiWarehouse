//
//  MockAuthService.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 19.04.2026.
//

import Foundation
@testable import cstatiWarehouse

final class MockAuthService: AuthServiceProtocol {

    private var currentUser: UserDTO?

    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let user = UserDTO(id: "1", name: "User", lastName: "", email: request.email, avatarURL: nil)
            self?.currentUser = user
            completion(.success(LoginResponse(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                user: user
            )))
        }
    }

    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let user = UserDTO(id: "1", name: request.name, lastName: request.lastName, email: request.email, avatarURL: request.avatarURL)
            self?.currentUser = user
            completion(.success(RegisterResponse(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                user: user
            )))
        }
    }

    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let payload = TelegramIDTokenPayload.decode(idToken: request.idToken) else {
                completion(.failure(.serverError("Некорректный Telegram id_token")))
                return
            }
            let displayName = payload.name?.trimmingCharacters(in: .whitespaces).nonEmpty
                ?? payload.preferredUsername?.trimmingCharacters(in: .whitespaces).nonEmpty
                ?? "Пользователь Telegram"
            let email = payload.preferredUsername.map { "\($0)@telegram.local" }
                ?? "tg_\(payload.sub)@telegram.local"
            let avatar = payload.pictureURL.flatMap { URL(string: $0) }
            let user = UserDTO(id: payload.sub, name: displayName, lastName: "", email: email, avatarURL: avatar)
            self?.currentUser = user
            completion(.success(LoginResponse(
                accessToken: "mock-tg-access",
                refreshToken: "mock-tg-refresh",
                user: user
            )))
        }
    }

    func loginWithGoogle(request: GoogleLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let user = UserDTO(id: "mock-google", name: "Google", lastName: "Тест", email: "google.mock@example.com", avatarURL: nil)
            self?.currentUser = user
            completion(.success(LoginResponse(
                accessToken: "mock-google-access",
                refreshToken: "mock-google-refresh",
                user: user
            )))
        }
    }

    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let current = self.currentUser else {
                completion(.failure(.unauthorized))
                return
            }
            let newName = request.name?.trimmingCharacters(in: .whitespaces) ?? current.name
            let newLastName = request.lastName?.trimmingCharacters(in: .whitespaces) ?? current.lastName
            let newAvatar: URL?
            switch request.avatarURL {
            case .some(let inner): newAvatar = inner
            case .none: newAvatar = current.avatarURL
            }
            let updated = UserDTO(id: current.id, name: newName, lastName: newLastName, email: current.email, avatarURL: newAvatar)
            self.currentUser = updated
            completion(.success(updated))
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
