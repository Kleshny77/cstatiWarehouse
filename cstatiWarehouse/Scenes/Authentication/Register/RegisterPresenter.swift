//
//  RegisterPresenter.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation
import SwiftUI

protocol RegisterPresenterProtocol: AnyObject {
  func viewDidLoad()
  func validatePassword(_ password: String) -> PasswordValidation
  func registerButtonTapped(name: String, email: String, password: String)
  func loginButtonTapped()
}

@Observable
final class RegisterPresenter: RegisterPresenterProtocol {
  var interactor: RegisterInteractorInputProtocol?
  var router: RegisterRouterProtocol?
  
  var errorMessage: String?
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
  
  func registerButtonTapped(name: String, email: String, password: String) {
    interactor?.register(name: name, email: email, password: password)
  }
  
  func loginButtonTapped() {
    router?.navigateToLogin()
  }
}

extension RegisterPresenter: RegisterInteractorOutputProtocol {
  func registrationSuccess() {
    router?.navigateToMain()
  }
  
  func registrationFailure(error: String) {
    errorMessage = error
  }
}
