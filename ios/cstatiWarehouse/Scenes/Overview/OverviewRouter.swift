//
//  OverviewRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol OverviewRouterProtocol: AnyObject {
    func openWarehouseFiltered(byCategory filterKey: String)
}

final class OverviewRouter: OverviewRouterProtocol {

    private let tabCoordinator: MainTabCoordinator

    init(tabCoordinator: MainTabCoordinator) {
        self.tabCoordinator = tabCoordinator
    }

    func openWarehouseFiltered(byCategory filterKey: String) {
        tabCoordinator.requestWarehouseCategoryFocus(filterKey: filterKey)
    }
}
