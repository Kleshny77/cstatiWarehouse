//
//  SettingsRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol SettingsRouterProtocol: AnyObject {
    func navigateToLogin()
}

final class SettingsRouter: SettingsRouterProtocol {
    
    
    private let appCoordinator: AppCoordinatorProtocol
    
    
    init(appCoordinator: AppCoordinatorProtocol) {
        self.appCoordinator = appCoordinator
    }
    
    
    func navigateToLogin() {
        appCoordinator.popToRoot()
    }
}
