//
// RegisterPresenter.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import Foundation
import SwiftUI
import UIKit

protocol RegisterPresenterProtocol: AnyObject {
    func viewDidLoad()
    func validatePassword(_ password: String) -> PasswordValidation
    func registerButtonTapped(name: String, lastName: String, email: String, password: String, avatar: UIImage?)
    func loginButtonTapped()
    func telegramLoginButtonTapped()
    func googleLoginButtonTapped()
}

@Observable
final class RegisterPresenter: RegisterPresenterProtocol {
    var interactor: RegisterInteractorInputProtocol?
    var router: RegisterRouterProtocol?

    var errorMessage: String?
    var isOAuthLoginInProgress: Bool = false
    var passwordValidation: PasswordValidation = PasswordValidation(
        minLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasDigit: false,
        hasSpecialCharacter: false
    )

    func viewDidLoad() {

    }

    func validatePassword(_ password: String) -> PasswordValidation {
        let result = interactor?.validatePassword(password) ?? PasswordValidation(
            minLength: false,
            hasUppercase: false,
            hasLowercase: false,
            hasDigit: false,
            hasSpecialCharacter: false
        )
        passwordValidation = result
        return result
    }

    func registerButtonTapped(name: String, lastName: String, email: String, password: String, avatar: UIImage?) {
        interactor?.register(name: name, lastName: lastName, email: email, password: password, avatar: avatar)
    }

    func loginButtonTapped() {
        router?.navigateToLogin()
    }

    func telegramLoginButtonTapped() {
        guard !isOAuthLoginInProgress else { return }
        isOAuthLoginInProgress = true
        interactor?.registerWithTelegram()
    }

    func googleLoginButtonTapped() {
        guard !isOAuthLoginInProgress else { return }
        isOAuthLoginInProgress = true
        interactor?.loginWithGoogle()
    }
}

extension RegisterPresenter: RegisterInteractorOutputProtocol {
    func registrationSuccess() {
        isOAuthLoginInProgress = false
        router?.navigateToMain()
    }

    func registrationFailure(error: String) {
        isOAuthLoginInProgress = false
        errorMessage = error
    }

    func telegramLoginCancelled() {
        isOAuthLoginInProgress = false
    }

    func oauthLoginDismissed() {
        isOAuthLoginInProgress = false
    }
}
