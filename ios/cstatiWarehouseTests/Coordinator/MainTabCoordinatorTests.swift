//
//  MainTabCoordinatorTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Testing
@testable import cstatiWarehouse

@MainActor
struct MainTabCoordinatorTests {

    @Test
    func requestWarehouseCategoryFocus_switchesTabAndStoresPendingFilter() {
        let sut = MainTabCoordinator()
        sut.selectedTab = .overview

        sut.requestWarehouseCategoryFocus(filterKey: "категория А")

        #expect(sut.selectedTab == .warehouse)
        #expect(sut.takePendingWarehouseCategoryFilterKey() == "категория А")
        #expect(sut.takePendingWarehouseCategoryFilterKey() == nil)
    }
}
