//
// RegisterInteractor.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import Foundation
import UIKit

protocol RegisterInteractorInputProtocol: AnyObject {
    func validatePassword(_ password: String) -> PasswordValidation
    func register(name: String, lastName: String, email: String, password: String, avatar: UIImage?)
    func registerWithTelegram()
    func loginWithGoogle()
}

protocol RegisterInteractorOutputProtocol: AnyObject {
    func registrationSuccess()
    func registrationFailure(error: String)
    func telegramLoginCancelled()
    func oauthLoginDismissed()
}

final class RegisterInteractor: RegisterInteractorInputProtocol {
    weak var presenter: RegisterInteractorOutputProtocol?
    private let authService: AuthServiceProtocol
    private let sessionStorage: UserSessionStorageProtocol
    private let telegramAuthService: TelegramAuthServiceProtocol
    private let googleAuthService: GoogleAuthServiceProtocol
    private let uploadsService: UploadsServiceProtocol

    init(
        authService: AuthServiceProtocol,
        sessionStorage: UserSessionStorageProtocol,
        telegramAuthService: TelegramAuthServiceProtocol,
        googleAuthService: GoogleAuthServiceProtocol,
        uploadsService: UploadsServiceProtocol
    ) {
        self.authService = authService
        self.sessionStorage = sessionStorage
        self.telegramAuthService = telegramAuthService
        self.googleAuthService = googleAuthService
        self.uploadsService = uploadsService
    }

    func validatePassword(_ password: String) -> PasswordValidation {
        PasswordValidation.validate(password)
    }

    func register(name: String, lastName: String, email: String, password: String, avatar: UIImage?) {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        guard !nameTrimmed.isEmpty else {
            presenter?.registrationFailure(error: "Введите имя")
            return
        }
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            presenter?.registrationFailure(error: "Введите email")
            return
        }
        guard email.contains("@") && email.contains(".") else {
            presenter?.registrationFailure(error: "Некорректный email")
            return
        }
        let passwordValidation = PasswordValidation.validate(password)
        guard passwordValidation.isValid else {
            presenter?.registrationFailure(error: "Пароль не соответствует требованиям")
            return
        }

        uploadAvatarIfNeeded(avatar) { [weak self] avatarURL in
            self?.performRegister(
                name: nameTrimmed,
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                email: email,
                password: password,
                avatarURL: avatarURL
            )
        }
    }

    func registerWithTelegram() {
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
                        self?.presenter?.registrationSuccess()
                    case .failure(let error):
                        self?.presenter?.registrationFailure(error: error.message)
                    }
                }
            case .failure(let error):
                if case .cancelled = error {
                    self.presenter?.telegramLoginCancelled()
                } else {
                    self.presenter?.registrationFailure(error: error.message)
                }
            }
        }
    }

    func loginWithGoogle() {
        googleAuthService.signIn { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let g):
                self.authService.loginWithGoogle(request: GoogleLoginRequest(idToken: g.idToken)) { [weak self] authResult in
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
                        self?.presenter?.registrationSuccess()
                    case .failure(let error):
                        self?.presenter?.registrationFailure(error: error.message)
                    }
                }
            case .failure(let error):
                if case .cancelled = error {
                    self.presenter?.oauthLoginDismissed()
                } else {
                    let msg = error.message
                    if msg.isEmpty {
                        self.presenter?.oauthLoginDismissed()
                    } else {
                        self.presenter?.registrationFailure(error: msg)
                    }
                }
            }
        }
    }

    private func uploadAvatarIfNeeded(_ image: UIImage?, completion: @escaping (URL?) -> Void) {
        guard let image else {
            completion(nil)
            return
        }
        uploadsService.uploadImage(image) { [weak self] result in
            switch result {
            case .success(let url):
                completion(url)
            case .failure(let error):
                self?.presenter?.registrationFailure(error: error.message)
            }
        }
    }

    private func performRegister(name: String, lastName: String, email: String, password: String, avatarURL: URL?) {
        let request = RegisterRequest(name: name, lastName: lastName, email: email, password: password, avatarURL: avatarURL)
        authService.register(request: request) { [weak self] result in
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
                self?.presenter?.registrationSuccess()
            case .failure(let error):
                self?.presenter?.registrationFailure(error: error.message)
            }
        }
    }
}
