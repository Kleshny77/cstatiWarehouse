//
//  WarehouseSortEngineTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct WarehouseSortEngineTests {
    private let engine = WarehouseSortEngine()

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_800_000_000)
    private let t2 = Date(timeIntervalSince1970: 1_900_000_000)

    @Test
    func newest_ordersDescendingByCreatedAt() {
        let a = makeItem(name: "a", category: "c", createdAt: t0)
        let b = makeItem(name: "b", category: "c", createdAt: t2)
        let c = makeItem(name: "c", category: "c", createdAt: t1)
        let sorted = engine.sort([a, b, c], by: .newest)
        #expect(sorted.map(\.name) == ["b", "c", "a"])
    }

    @Test
    func oldest_ordersAscendingByCreatedAt() {
        let a = makeItem(name: "a", category: "c", createdAt: t2)
        let b = makeItem(name: "b", category: "c", createdAt: t0)
        let sorted = engine.sort([a, b], by: .oldest)
        #expect(sorted.map(\.name) == ["b", "a"])
    }

    @Test
    func quantityDesc_ordersByEffectiveQuantity() {
        let low = makeItem(name: "low", category: "c", quantity: 2, createdAt: t0)
        let high = makeItem(name: "high", category: "c", quantity: 99, createdAt: t0)
        let sorted = engine.sort([low, high], by: .quantityDesc)
        #expect(sorted.map(\.name) == ["high", "low"])
    }

    @Test
    func nameAsc_ordersAlphabetically() {
        let b = makeItem(name: "Бета", category: "c", createdAt: t0)
        let a = makeItem(name: "Альфа", category: "c", createdAt: t0)
        let sorted = engine.sort([b, a], by: .nameAsc)
        #expect(sorted.map(\.name) == ["Альфа", "Бета"])
    }

    private func makeItem(
        name: String,
        category: String,
        quantity: Int = 1,
        createdAt: Date,
        expirationDate: Date? = nil
    ) -> Item {
        Item(
            name: name,
            categoryName: category,
            quantity: quantity,
            expirationDate: expirationDate,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
