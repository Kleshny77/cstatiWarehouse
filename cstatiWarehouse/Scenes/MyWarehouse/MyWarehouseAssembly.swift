//
//  MyWarehouseAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

final class MyWarehouseAssembly {
    static func assemble(
        appCoordinator: AppCoordinatorProtocol,
        warehouseService: WarehouseServiceProtocol = AppServices.warehouseService(),
        organizationsService: OrganizationsServiceProtocol = AppServices.organizationsService(),
        activeOrgStorage: ActiveOrganizationStorageProtocol = AppServices.activeOrganizationStorage
    ) -> some View {
        let presenter = MyWarehousePresenter()
        let interactor = MyWarehouseInteractor(
            warehouseService: warehouseService,
            organizationsService: organizationsService,
            eventsService: AppServices.eventsService(),
            activeOrgStorage: activeOrgStorage
        )
        let router = MyWarehouseRouter(
            appCoordinator: appCoordinator,
            warehouseService: warehouseService,
            organizationsService: organizationsService
        )

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return MyWarehouseView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
