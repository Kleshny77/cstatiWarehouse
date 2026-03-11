//
//  RegisterInteractor.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

protocol RegisterInteractorInputProtocol: AnyObject {
  func validatePassword(_ password: String) -> PasswordValidation
  func register(name: String, email: String, password: String)
}

protocol RegisterInteractorOutputProtocol: AnyObject {
  func registrationSuccess()
  func registrationFailure(error: String)
}

final class RegisterInteractor: RegisterInteractorInputProtocol {
  weak var presenter: RegisterInteractorOutputProtocol?
  private let authService: AuthServiceProtocol
  
  init(authService: AuthServiceProtocol) {
    self.authService = authService
  }
  
  func validatePassword(_ password: String) -> PasswordValidation {
    PasswordValidation.validate(password)
  }
  
  func register(name: String, email: String, password: String) {
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
    
    let request = RegisterRequest(name: nameTrimmed, email: email, password: password)
    authService.register(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.presenter?.registrationSuccess()
      case .failure(let error):
        self?.presenter?.registrationFailure(error: error.message)
      }
    }
  }
}
