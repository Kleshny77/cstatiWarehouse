//
//  MyWarehouseAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

final class MyWarehouseAssembly {

    /// Единый презентер и зависимости для вкладки склада — не создавать заново на каждый body TabBarView,
    /// иначе асинхронные ответы API могут теряться в освобождённом экземпляре (пустой экран до смены таба).
    static func makePresenter(
        appCoordinator: AppCoordinatorProtocol,
        warehouseService: WarehouseServiceProtocol = AppServices.warehouseService(),
        organizationsService: OrganizationsServiceProtocol = AppServices.organizationsService(),
        activeOrgStorage: ActiveOrganizationStorageProtocol = AppServices.activeOrganizationStorage
    ) -> MyWarehousePresenter {
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
        presenter.shelfLifeNotifier = AppServices.shelfLifeNotifier
        interactor.presenter = presenter
        return presenter
    }

    static func assemble(
        tabCoordinator: MainTabCoordinator,
        presenter: MyWarehousePresenter
    ) -> some View {
        presenter.tabCoordinator = tabCoordinator

        return MyWarehouseView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
                presenter.handleWarehouseTabAppeared()
            }
            .onChange(of: tabCoordinator.selectedTab) { _, tab in
                guard tab == .warehouse else { return }
                presenter.handleWarehouseTabAppeared()
            }
    }
}
