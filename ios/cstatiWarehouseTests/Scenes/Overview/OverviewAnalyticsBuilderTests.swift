//
//  OverviewAnalyticsBuilderTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import XCTest
@testable import cstatiWarehouse

final class OverviewAnalyticsBuilderTests: XCTestCase {

    func testCategoryRowsAggregatesRootsAndIgnoresVariants() {
        let parentID = UUID()
        let items = [
            Item(name: "Стол", categoryName: "Мебель", quantity: 2, parentItemID: nil),
            Item(name: "Стул", categoryName: "Мебель", quantity: 3, parentItemID: nil),
            Item(name: "Вариант", categoryName: "Еда", quantity: 10, parentItemID: parentID)
        ]

        let rows = OverviewAnalyticsBuilder.categoryRows(from: items)

        XCTAssertEqual(rows.count, 1)
        let furniture = rows.first { $0.title == "Мебель" }
        XCTAssertEqual(furniture?.totalUnits, 5)
        XCTAssertEqual(furniture?.filterKey, "Мебель")
        XCTAssertTrue(furniture?.canNavigateToWarehouse ?? false)
    }

    func testEmptyCategoryMapsFilterKeyToEmptyString() {
        let items = [
            Item(name: "Без кат", categoryName: "   ", quantity: 4, parentItemID: nil)
        ]

        let rows = OverviewAnalyticsBuilder.categoryRows(from: items)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.title, "Без категории")
        XCTAssertEqual(rows.first?.filterKey, "")
        XCTAssertTrue(rows.first?.canNavigateToWarehouse ?? false)
    }

    func testShelfRiskBucketsExpiredAndWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 12))!

        let expiredDate = calendar.date(byAdding: .day, value: -5, to: anchor)!
        let soonDate = calendar.date(byAdding: .day, value: 3, to: anchor)!

        let expiredLine = Item(
            name: "Просрочено",
            categoryName: "Еда",
            quantity: 1,
            expirationDate: expiredDate,
            parentItemID: nil
        )
        let soonLine = Item(
            name: "Скоро",
            categoryName: "Еда",
            quantity: 1,
            expirationDate: soonDate,
            parentItemID: nil
        )

        let rows = OverviewAnalyticsBuilder.shelfRiskRows(from: [expiredLine, soonLine], now: anchor, calendar: calendar)

        let expiredCount = rows.first { $0.band == .expired }?.lineCount ?? -1
        let weekCount = rows.first { $0.band == .withinWeek }?.lineCount ?? -1

        XCTAssertEqual(expiredCount, 1)
        XCTAssertEqual(weekCount, 1)
    }

    func testShelfRiskSafeBandForFarExpiry() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 4, day: 26))!
        let far = calendar.date(byAdding: .day, value: 90, to: anchor)!

        let line = Item(
            name: "Далеко",
            categoryName: "Техника",
            quantity: 1,
            expirationDate: far,
            parentItemID: nil
        )

        let rows = OverviewAnalyticsBuilder.shelfRiskRows(from: [line], now: anchor, calendar: calendar)
        let safe = rows.first { $0.band == .safeOrNoShelf }?.lineCount ?? 0

        XCTAssertEqual(safe, 1)
        XCTAssertEqual(rows.first { $0.band == .expired }?.lineCount ?? 0, 0)
    }
}
