//
//  LoginInteractor.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

protocol LoginInteractorInputProtocol: AnyObject {
  func login(email: String, password: String)
}

protocol LoginInteractorOutputProtocol: AnyObject {
  func loginSuccess()
  func loginFailure(error: String)
}

final class LoginInteractor: LoginInteractorInputProtocol {
  weak var presenter: LoginInteractorOutputProtocol?
  private let authService: AuthServiceProtocol
  
  init(authService: AuthServiceProtocol) {
    self.authService = authService
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
      case .success:
        self?.presenter?.loginSuccess()
      case .failure(let error):
        self?.presenter?.loginFailure(error: error.message)
      }
    }
  }
}
