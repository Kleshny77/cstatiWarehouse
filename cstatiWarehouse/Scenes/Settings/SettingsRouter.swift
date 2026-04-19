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
    
    // MARK: Properties
    
    private let appCoordinator: AppCoordinatorProtocol
    
    // MARK: Lifecycle
    
    init(appCoordinator: AppCoordinatorProtocol) {
        self.appCoordinator = appCoordinator
    }
    
    // MARK: Public Methods
    
    func navigateToLogin() {
        appCoordinator.popToRoot()
    }
}
