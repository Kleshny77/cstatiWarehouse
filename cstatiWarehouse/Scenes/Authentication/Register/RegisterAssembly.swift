//
//  RegisterAssembly.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

final class RegisterAssembly {
    static func assemble(
        appCoordinator: AppCoordinatorProtocol,
        authService: AuthServiceProtocol = AppServices.authService(),
        sessionStorage: UserSessionStorageProtocol = AppServices.sessionStorage,
        telegramAuthService: TelegramAuthServiceProtocol = TelegramLoginAuthService(),
        uploadsService: UploadsServiceProtocol = AppServices.uploadsService()
    ) -> some View {
        let presenter = RegisterPresenter()
        let interactor = RegisterInteractor(
            authService: authService,
            sessionStorage: sessionStorage,
            telegramAuthService: telegramAuthService,
            uploadsService: uploadsService
        )
        let router = RegisterRouter(appCoordinator: appCoordinator)
        
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        
        return RegisterView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}

