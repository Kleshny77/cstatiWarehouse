//
// MainTabCoordinator.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import Observation

@Observable
final class MainTabCoordinator {

    enum Tab: Hashable {
        case warehouse
        case organization
        case overview
    }

    var selectedTab: Tab = .warehouse
    private(set) var pendingWarehouseCategoryFilterKey: String?

    func requestWarehouseCategoryFocus(filterKey: String) {
        pendingWarehouseCategoryFilterKey = filterKey
        selectedTab = .warehouse
    }

    func takePendingWarehouseCategoryFilterKey() -> String? {
        let value = pendingWarehouseCategoryFilterKey
        pendingWarehouseCategoryFilterKey = nil
        return value
    }
}
