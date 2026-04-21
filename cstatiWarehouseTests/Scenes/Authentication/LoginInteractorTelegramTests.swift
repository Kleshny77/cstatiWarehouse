//
//  LoginInteractorTelegramTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Testing
@testable import cstatiWarehouse
import Foundation

@Suite("LoginInteractor.loginWithTelegram")
struct LoginInteractorTelegramTests {
    
    @Test
    func happyPath_savesSessionAndNotifiesSuccess() async {
        let output = SpyOutput()
        let storage = SpySessionStorage()
        let authService = SpyAuthService(telegramResult: .success(LoginResponse(
            accessToken: "srv-token",
            refreshToken: "srv-refresh",
            user: UserDTO(id: "42", name: "Иван", lastName: "", email: "ivan@tg.local", avatarURL: nil)
        )))
        let telegramService = MockTelegramAuthService(result: .success(
            TelegramAuthResult(idToken: "any-token")
        ))
        let sut = LoginInteractor(
            authService: authService,
            sessionStorage: storage,
            telegramAuthService: telegramService
        )
        sut.presenter = output
        
        sut.loginWithTelegram()
        await waitForCallbacks()
        
        #expect(authService.lastTelegramIdToken == "any-token")
        #expect(storage.savedUser?.name == "Иван")
        #expect(storage.savedAccessToken == "srv-token")
        #expect(storage.savedRefreshToken == "srv-refresh")
        #expect(output.successes == 1)
        #expect(output.failures.isEmpty)
        #expect(output.cancellations == 0)
    }
    
    @Test
    func cancellation_doesNotCallAuthServiceAndReportsCancellation() async {
        let output = SpyOutput()
        let storage = SpySessionStorage()
        let authService = SpyAuthService(telegramResult: .success(LoginResponse(
            accessToken: "unused", refreshToken: "unused-r",
            user: UserDTO(id: "x", name: "x", lastName: "", email: "x", avatarURL: nil)
        )))
        let telegramService = MockTelegramAuthService(result: .failure(.cancelled))
        let sut = LoginInteractor(
            authService: authService,
            sessionStorage: storage,
            telegramAuthService: telegramService
        )
        sut.presenter = output
        
        sut.loginWithTelegram()
        await waitForCallbacks()
        
        #expect(authService.lastTelegramIdToken == nil)
        #expect(storage.savedUser == nil)
        #expect(output.successes == 0)
        #expect(output.cancellations == 1)
        #expect(output.failures.isEmpty)
    }
    
    @Test
    func notConfigured_reportsFailure() async {
        let output = SpyOutput()
        let storage = SpySessionStorage()
        let authService = SpyAuthService(telegramResult: .success(LoginResponse(
            accessToken: "unused", refreshToken: "unused-r",
            user: UserDTO(id: "x", name: "x", lastName: "", email: "x", avatarURL: nil)
        )))
        let telegramService = MockTelegramAuthService(result: .failure(.notConfigured))
        let sut = LoginInteractor(
            authService: authService,
            sessionStorage: storage,
            telegramAuthService: telegramService
        )
        sut.presenter = output
        
        sut.loginWithTelegram()
        await waitForCallbacks()
        
        #expect(output.successes == 0)
        #expect(output.cancellations == 0)
        #expect(output.failures.count == 1)
        #expect(output.failures.first?.contains("не настроен") == true)
    }
    
    @Test
    func backendFailure_reportsFailureAndDoesNotSaveSession() async {
        let output = SpyOutput()
        let storage = SpySessionStorage()
        let authService = SpyAuthService(telegramResult: .failure(.serverError("5xx")))
        let telegramService = MockTelegramAuthService(result: .success(
            TelegramAuthResult(idToken: "token")
        ))
        let sut = LoginInteractor(
            authService: authService,
            sessionStorage: storage,
            telegramAuthService: telegramService
        )
        sut.presenter = output
        
        sut.loginWithTelegram()
        await waitForCallbacks()
        
        #expect(authService.lastTelegramIdToken == "token")
        #expect(storage.savedUser == nil)
        #expect(output.successes == 0)
        #expect(output.failures.count == 1)
    }
    
    // MARK: Private Methods
    
    private func waitForCallbacks() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
    }
}

// MARK: - Spies

private final class SpyOutput: LoginInteractorOutputProtocol {
    var successes: Int = 0
    var failures: [String] = []
    var cancellations: Int = 0
    
    func loginSuccess() {
        successes += 1
    }
    
    func loginFailure(error: String) {
        failures.append(error)
    }
    
    func telegramLoginCancelled() {
        cancellations += 1
    }
}

private final class SpySessionStorage: UserSessionStorageProtocol {
    private(set) var savedUser: User?
    private(set) var savedAccessToken: String?
    private(set) var savedRefreshToken: String?
    
    var currentUser: User? { savedUser }
    var accessToken: String? { savedAccessToken }
    var refreshToken: String? { savedRefreshToken }
    var isLoggedIn: Bool { savedUser != nil }
    
    func save(user: User, accessToken: String, refreshToken: String) {
        savedUser = user
        savedAccessToken = accessToken
        savedRefreshToken = refreshToken
    }
    
    func updateTokens(accessToken: String, refreshToken: String) {
        savedAccessToken = accessToken
        savedRefreshToken = refreshToken
    }

    func updateUser(_ user: User) {
        savedUser = user
    }

    func clear() {
        savedUser = nil
        savedAccessToken = nil
        savedRefreshToken = nil
    }
}

private final class SpyAuthService: AuthServiceProtocol {
    private let telegramResult: Result<LoginResponse, AuthError>
    private(set) var lastTelegramIdToken: String?
    
    init(telegramResult: Result<LoginResponse, AuthError>) {
        self.telegramResult = telegramResult
    }
    
    func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("not used")))
    }
    
    func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
        completion(.failure(.serverError("not used")))
    }
    
    func loginWithTelegram(request: TelegramLoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        lastTelegramIdToken = request.idToken
        DispatchQueue.main.async { [telegramResult] in
            completion(telegramResult)
        }
    }
    
    func updateProfile(request: UpdateProfileRequest, completion: @escaping (Result<UserDTO, AuthError>) -> Void) {
        completion(.failure(.serverError("not used")))
    }
}
