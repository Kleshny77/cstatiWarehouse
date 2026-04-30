//
// OrganizationRouter.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

protocol OrganizationRouterProtocol: AnyObject {
}

final class OrganizationRouter: OrganizationRouterProtocol {


    private weak var appCoordinator: AppCoordinatorProtocol?


    init(appCoordinator: AppCoordinatorProtocol) {
        self.appCoordinator = appCoordinator
    }
}
