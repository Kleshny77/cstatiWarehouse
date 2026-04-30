//
//  OverviewPresenterTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct OverviewPresenterTests {

    @Test
    func analyticsLoaded_updatesMetricsSnapshotAndStopsLoading() {
        let sut = OverviewPresenter()

        let metrics = DashboardMetrics(
            totalItems: 1,
            inStockItems: 1,
            archivedItems: 0,
            expiringSoon: 0,
            categoriesCount: 1,
            stockTrend: [],
            categoryDistribution: [],
            expiringItems: []
        )
        let snapshot = OverviewAnalyticsBuilder.makeSnapshot(organizationTitle: "Тест", items: [])

        sut.analyticsLoaded(metrics, snapshot: snapshot, organizationTitle: "Тест")

        #expect(sut.isLoading == false)
        #expect(sut.metrics?.totalItems == 1)
        #expect(sut.organizationTitle == "Тест")
        #expect(sut.overviewSnapshot != nil)
    }

    @Test
    func loadFailed_withoutCachedMetrics_setsErrorMessage() {
        let sut = OverviewPresenter()
        sut.metrics = nil

        sut.loadFailed(message: "ошибка")

        #expect(sut.errorMessage == "ошибка")
        #expect(sut.isLoading == false)
    }

    @Test
    func loadFailed_withCachedMetrics_setsPassiveNotice() {
        let sut = OverviewPresenter()
        sut.metrics = DashboardMetrics(
            totalItems: 0,
            inStockItems: 0,
            archivedItems: 0,
            expiringSoon: 0,
            categoriesCount: 0,
            stockTrend: [],
            categoryDistribution: [],
            expiringItems: []
        )

        sut.loadFailed(message: "сеть")

        #expect(sut.passiveNoticeMessage == "сеть")
        #expect(sut.errorMessage == nil)
    }
}
