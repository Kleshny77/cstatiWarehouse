//
//  LoginInteractor.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

protocol LoginInteractorInputProtocol: AnyObject {
    func login(email: String, password: String)
    func loginWithTelegram()
}

protocol LoginInteractorOutputProtocol: AnyObject {
    func loginSuccess()
    func loginFailure(error: String)
    func telegramLoginCancelled()
}

final class LoginInteractor: LoginInteractorInputProtocol {
    weak var presenter: LoginInteractorOutputProtocol?
    private let authService: AuthServiceProtocol
    private let sessionStorage: UserSessionStorageProtocol
    private let telegramAuthService: TelegramAuthServiceProtocol
    
    init(
        authService: AuthServiceProtocol,
        sessionStorage: UserSessionStorageProtocol,
        telegramAuthService: TelegramAuthServiceProtocol
    ) {
        self.authService = authService
        self.sessionStorage = sessionStorage
        self.telegramAuthService = telegramAuthService
    }
    
    func login(email: String, password: String) {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            presenter?.loginFailure(error: "Введите email")
            return
        }
        guard !password.isEmpty else {
            presenter?.loginFailure(error: "Введите пароль")
            return
        }
        guard email.contains("@") else {
            presenter?.loginFailure(error: "Некорректный email")
            return
        }
        
        let request = LoginRequest(email: email, password: password)
        authService.login(request: request) { [weak self] result in
            switch result {
            case .success(let response):
                let user = User(
                    id: response.user.id,
                    email: response.user.email,
                    name: response.user.name,
                    lastName: response.user.lastName,
                    avatarURL: response.user.avatarURL
                )
                self?.sessionStorage.save(
                    user: user,
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                self?.presenter?.loginSuccess()
            case .failure(let error):
                self?.presenter?.loginFailure(error: error.message)
            }
        }
    }
    
    func loginWithTelegram() {
        telegramAuthService.signIn { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let telegramResult):
                let request = TelegramLoginRequest(idToken: telegramResult.idToken)
                self.authService.loginWithTelegram(request: request) { [weak self] authResult in
                    switch authResult {
                    case .success(let response):
                        let user = User(
                            id: response.user.id,
                            email: response.user.email,
                            name: response.user.name,
                            lastName: response.user.lastName,
                            avatarURL: response.user.avatarURL
                        )
                        self?.sessionStorage.save(
                            user: user,
                            accessToken: response.accessToken,
                            refreshToken: response.refreshToken
                        )
                        self?.presenter?.loginSuccess()
                    case .failure(let error):
                        self?.presenter?.loginFailure(error: error.message)
                    }
                }
            case .failure(let error):
                if case .cancelled = error {
                    self.presenter?.telegramLoginCancelled()
                } else {
                    self.presenter?.loginFailure(error: error.message)
                }
            }
        }
    }
}
