//
//  RegisterRouter.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

protocol RegisterRouterProtocol: AnyObject {
  func navigateToLogin()
  func navigateToMain()
}

final class RegisterRouter: RegisterRouterProtocol {
  private weak var appCoordinator: AppCoordinatorProtocol?
  
  init(appCoordinator: AppCoordinatorProtocol) {
    self.appCoordinator = appCoordinator
  }
  
  func navigateToLogin() {
    appCoordinator?.pop()
  }
  
  func navigateToMain() {
    appCoordinator?.popToRoot()
    appCoordinator?.navigate(to: .main)
  }
}
