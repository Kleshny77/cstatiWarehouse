//
//  DashboardMetricsCodableTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct DashboardMetricsCodableTests {

    @Test
    func roundtrip_preservesFields() throws {
        let cal = Calendar(identifier: .gregorian)
        let d1 = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10)))
        let expId = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!

        let original = DashboardMetrics(
            totalItems: 3,
            inStockItems: 2,
            archivedItems: 1,
            expiringSoon: 1,
            categoriesCount: 2,
            stockTrend: [StockDataPoint(date: d1, quantity: 5)],
            categoryDistribution: [CategoryDistribution(categoryName: "КатА", count: 2)],
            expiringItems: [
                ExpiringItem(
                    id: expId,
                    name: "Товар",
                    quantity: 1,
                    expirationDate: d1,
                    daysUntil: 2
                )
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DashboardMetrics.self, from: data)

        #expect(decoded.totalItems == original.totalItems)
        #expect(decoded.stockTrend.count == 1)
        #expect(decoded.categoryDistribution.first?.categoryName == "КатА")
        #expect(decoded.expiringItems.first?.id == expId)
    }
}
