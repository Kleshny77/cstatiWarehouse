//
//  SettingsAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

final class SettingsAssembly {
    static func assemble(
        appCoordinator: AppCoordinatorProtocol,
        sessionStorage: UserSessionStorageProtocol = AppServices.sessionStorage,
        authService: AuthServiceProtocol = AppServices.authService(),
        uploadsService: UploadsServiceProtocol = AppServices.uploadsService()
    ) -> some View {
        let presenter = SettingsPresenter()
        let interactor = SettingsInteractor(
            sessionStorage: sessionStorage,
            authService: authService,
            uploadsService: uploadsService
        )
        let router = SettingsRouter(appCoordinator: appCoordinator)

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return SettingsView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
