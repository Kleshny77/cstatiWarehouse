//
// LoginPresenter.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import Foundation
import SwiftUI

protocol LoginPresenterProtocol: AnyObject {
    func viewDidLoad()
    func loginButtonTapped(email: String, password: String)
    func registerButtonTapped()
    func telegramLoginButtonTapped()
    func googleLoginButtonTapped()
}

@Observable
final class LoginPresenter: LoginPresenterProtocol {
    var interactor: LoginInteractorInputProtocol?
    var router: LoginRouterProtocol?

    var errorMessage: String?
    var isOAuthLoginInProgress: Bool = false

    func viewDidLoad() {

    }

    func loginButtonTapped(email: String, password: String) {
        interactor?.login(email: email, password: password)
    }

    func registerButtonTapped() {
        router?.navigateToRegister()
    }

    func telegramLoginButtonTapped() {
        guard !isOAuthLoginInProgress else { return }
        isOAuthLoginInProgress = true
        interactor?.loginWithTelegram()
    }

    func googleLoginButtonTapped() {
        guard !isOAuthLoginInProgress else { return }
        isOAuthLoginInProgress = true
        interactor?.loginWithGoogle()
    }
}

extension LoginPresenter: LoginInteractorOutputProtocol {
    func loginSuccess() {
        isOAuthLoginInProgress = false
        router?.navigateToMain()
    }

    func loginFailure(error: String) {
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
