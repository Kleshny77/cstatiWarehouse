//
//  LoginRouter.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

protocol LoginRouterProtocol: AnyObject {
  func navigateToMain()
  func navigateToRegister()
}

final class LoginRouter: LoginRouterProtocol {
  private weak var appCoordinator: AppCoordinatorProtocol?
  
  init(appCoordinator: AppCoordinatorProtocol) {
    self.appCoordinator = appCoordinator
  }
  
  func navigateToMain() {
    appCoordinator?.navigate(to: .main)
  }
  
  func navigateToRegister() {
    appCoordinator?.navigate(to: .register)
  }
}
