//
//  RegisterPresenter.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
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
}

@Observable
final class RegisterPresenter: RegisterPresenterProtocol {
    var interactor: RegisterInteractorInputProtocol?
    var router: RegisterRouterProtocol?
    
    var errorMessage: String?
    var isTelegramLoginInProgress: Bool = false
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
        guard !isTelegramLoginInProgress else { return }
        isTelegramLoginInProgress = true
        interactor?.registerWithTelegram()
    }
}

extension RegisterPresenter: RegisterInteractorOutputProtocol {
    func registrationSuccess() {
        isTelegramLoginInProgress = false
        router?.navigateToMain()
    }
    
    func registrationFailure(error: String) {
        isTelegramLoginInProgress = false
        errorMessage = error
    }
    
    func telegramLoginCancelled() {
        isTelegramLoginInProgress = false
    }
}
