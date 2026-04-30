//
//  OverviewAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import SwiftUI

final class OverviewAssembly {

    static func makePresenter(
        tabCoordinator: MainTabCoordinator,
        analyticsService: AnalyticsServiceProtocol = AppServices.analyticsService(),
        organizationsService: OrganizationsServiceProtocol = AppServices.organizationsService(),
        warehouseService: WarehouseServiceProtocol = AppServices.warehouseService(),
        activeOrgStorage: ActiveOrganizationStorageProtocol = AppServices.activeOrganizationStorage
    ) -> OverviewPresenter {
        let presenter = OverviewPresenter()
        let interactor = OverviewInteractor(
            analyticsService: analyticsService,
            organizationsService: organizationsService,
            warehouseService: warehouseService,
            activeOrgStorage: activeOrgStorage
        )
        let router = OverviewRouter(tabCoordinator: tabCoordinator)

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        return presenter
    }

    static func assemble(presenter: OverviewPresenter) -> some View {
        OverviewView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
