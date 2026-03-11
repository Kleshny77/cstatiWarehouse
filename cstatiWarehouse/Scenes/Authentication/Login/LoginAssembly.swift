//
//  LoginAssembly.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

final class LoginAssembly {
  static func assemble(appCoordinator: AppCoordinatorProtocol, authService: AuthServiceProtocol = MockAuthService()) -> some View {
    let presenter = LoginPresenter()
    let interactor = LoginInteractor(authService: authService)
    let router = LoginRouter(appCoordinator: appCoordinator)
    
    presenter.interactor = interactor
    presenter.router = router
    interactor.presenter = presenter
    
    return LoginView(presenter: presenter)
      .onAppear {
        presenter.viewDidLoad()
      }
  }
}
