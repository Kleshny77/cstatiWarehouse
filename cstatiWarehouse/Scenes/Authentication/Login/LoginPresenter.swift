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
}

@Observable
final class LoginPresenter: LoginPresenterProtocol {
  var interactor: LoginInteractorInputProtocol?
  var router: LoginRouterProtocol?
  
  var errorMessage: String?
  
  func viewDidLoad() {
    
  }
  
  func loginButtonTapped(email: String, password: String) {
    interactor?.login(email: email, password: password)
  }
  
  func registerButtonTapped() {
    router?.navigateToRegister()
  }
}

extension LoginPresenter: LoginInteractorOutputProtocol {
  func loginSuccess() {
    router?.navigateToMain()
  }
  
  func loginFailure(error: String) {
    errorMessage = error
  }
}
