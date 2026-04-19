//
//  LoginPresenter.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation
import SwiftUI

protocol LoginPresenterProtocol: AnyObject {
    func viewDidLoad()
    func loginButtonTapped(email: String, password: String)
    func registerButtonTapped()
    func telegramLoginButtonTapped()
}

@Observable
final class LoginPresenter: LoginPresenterProtocol {
    var interactor: LoginInteractorInputProtocol?
    var router: LoginRouterProtocol?
    
    var errorMessage: String?
    var isTelegramLoginInProgress: Bool = false
    
    func viewDidLoad() {
        
    }
    
    func loginButtonTapped(email: String, password: String) {
        interactor?.login(email: email, password: password)
    }
    
    func registerButtonTapped() {
        router?.navigateToRegister()
    }
    
    func telegramLoginButtonTapped() {
        guard !isTelegramLoginInProgress else { return }
        isTelegramLoginInProgress = true
        interactor?.loginWithTelegram()
    }
}

extension LoginPresenter: LoginInteractorOutputProtocol {
    func loginSuccess() {
        isTelegramLoginInProgress = false
        router?.navigateToMain()
    }
    
    func loginFailure(error: String) {
        isTelegramLoginInProgress = false
        errorMessage = error
    }
    
    func telegramLoginCancelled() {
        isTelegramLoginInProgress = false
    }
}
