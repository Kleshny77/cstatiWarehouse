//
//  MyWarehouseRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

protocol MyWarehouseRouterProtocol: AnyObject {
    func navigateToProfile()
    func makeItemEditScene(
        mode: ItemEditMode,
        organizationID: UUID,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> ItemEditHostedScene
}

final class MyWarehouseRouter: MyWarehouseRouterProtocol {

    private weak var appCoordinator: AppCoordinatorProtocol?
    private let warehouseService: WarehouseServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol

    init(
        appCoordinator: AppCoordinatorProtocol,
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol
    ) {
        self.appCoordinator = appCoordinator
        self.warehouseService = warehouseService
        self.organizationsService = organizationsService
    }
    
    
    func navigateToProfile() {
        appCoordinator?.navigate(to: .profile)
    }
    
    func makeItemEditScene(
        mode: ItemEditMode,
        organizationID: UUID,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> ItemEditHostedScene {
        ItemEditAssembly.assemble(
            mode: mode,
            organizationID: organizationID,
            warehouseService: warehouseService,
            organizationsService: organizationsService,
            onFinish: onFinish
        )
    }
}
