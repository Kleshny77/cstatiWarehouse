//
//  RegisterInteractorValidationTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Testing
import UIKit
@testable import cstatiWarehouse

@Suite("RegisterInteractor.validation")
@MainActor
struct RegisterInteractorValidationTests {
    @Test
    func register_emptyName_reportsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.register(name: "   ", lastName: "", email: "a@b.co", password: "Abcd12345!", avatar: nil)
        #expect(spy.failures == ["Введите имя"])
    }

    @Test
    func register_emptyEmail_reportsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.register(name: "Иван", lastName: "", email: "   ", password: "Abcd12345!", avatar: nil)
        #expect(spy.failures == ["Введите email"])
    }

    @Test
    func register_invalidEmail_reportsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.register(name: "Иван", lastName: "", email: "not-an-email", password: "Abcd12345!", avatar: nil)
        #expect(spy.failures == ["Некорректный email"])
    }

    @Test
    func register_weakPassword_reportsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.register(name: "Иван", lastName: "", email: "a@b.co", password: "short", avatar: nil)
        #expect(spy.failures == ["Пароль не соответствует требованиям"])
    }

    @Test
    func register_validCredentials_callsAuthRegister() async {
        let auth = ImmediateRegisterAuthService()
        let storage = SpyRegisterSessionStorage()
        let sut = RegisterInteractor(
            authService: auth,
            sessionStorage: storage,
            telegramAuthService: UnusedTelegramAuthService(),
            googleAuthService: UnusedGoogleAuthService(),
            uploadsService: ImmediateUploadsService()
        )
        let spy = RegisterPresenterSpy()
        sut.presenter = spy

        sut.register(name: "Иван", lastName: "П.", email: "ivan@mail.co", password: "Abcd12345!", avatar: nil)
        await drainMain()

        #expect(auth.registerCallCount == 1)
        #expect(spy.successCount == 1)
        #expect(storage.savedAccessToken == "acc")
    }

    private func makeSUT() -> (RegisterInteractor, RegisterPresenterSpy, SpyRegisterSessionStorage) {
        let spy = RegisterPresenterSpy()
        let storage = SpyRegisterSessionStorage()
        let sut = RegisterInteractor(
            authService: DisabledAuthService(),
            sessionStorage: storage,
            telegramAuthService: UnusedTelegramAuthService(),
            googleAuthService: UnusedGoogleAuthService(),
            uploadsService: ImmediateUploadsService()
        )
        sut.presenter = spy
        return (sut, spy, storage)
    }

    private func drainMain() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
    }
}

private final class RegisterPresenterSpy: RegisterInteractorOutputProtocol {
    var failures: [String] = []
    var successCount = 0

    func registrationSuccess() { successCount += 1 }
    func registrationFailure(error: String) { failures.append(error) }
    func telegramLoginCancelled() {}
    func oauthLoginDismissed() {}
}

private final class SpyRegisterSessionStorage: UserSessionStorageProtocol {
    private(set) var savedUser: User?
    private(set) var savedAccessToken: String?

    var currentUser: User? { savedUser }
    var accessToken: String? { savedAccessToken }
    var refreshToken: String? { nil }
    var isLoggedIn: Bool { false }

    func save(user: User, accessToken: String, refreshToken: String) {
        savedUser = user
        savedAccessToken = accessToken
    }

    func updateTokens(accessToken: String, refreshToken: String) {}
    func updateUser(_ user: User) {}
    func clear() {}
}

private final class DisabledAuthService: AuthServiceProtocol {
    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func loginWithGoogle(request: GoogleLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }
}

private final class ImmediateRegisterAuthService: AuthServiceProtocol {
    private(set) var registerCallCount = 0

    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
        registerCallCount += 1
        DispatchQueue.main.async {
            let user = UserDTO(
                id: "reg-1",
                name: request.name,
                lastName: request.lastName,
                email: request.email,
                avatarURL: request.avatarURL
            )
            completion(.success(RegisterResponse(
                accessToken: "acc",
                refreshToken: "ref",
                user: user
            )))
        }
    }

    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func loginWithGoogle(request: GoogleLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }

    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void) {
        completion(.failure(.serverError("no")))
    }
}

private final class ImmediateUploadsService: UploadsServiceProtocol {
    func uploadImage(_ image: UIImage, completion: @escaping (Result<URL, UploadsError>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(URL(string: "https://example.com/a.png")!))
        }
    }
}

private final class UnusedTelegramAuthService: TelegramAuthServiceProtocol {
    func signIn(completion: @escaping (Result<TelegramAuthResult, TelegramAuthError>) -> Void) {
        completion(.failure(.notConfigured))
    }
}

private final class UnusedGoogleAuthService: GoogleAuthServiceProtocol {
    func signIn(completion: @escaping (Result<GoogleAuthResult, GoogleAuthError>) -> Void) {
        completion(.failure(.notConfigured))
    }
}
