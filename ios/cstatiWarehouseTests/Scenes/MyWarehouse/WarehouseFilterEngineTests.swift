//
//  WarehouseFilterEngineTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct WarehouseFilterEngineTests {
    private let engine = WarehouseFilterEngine()

    @Test
    func categoryFilter_trimsWhitespace() {
        let a = makeItem(name: "a", category: "Напитки", createdAt: .now)
        let b = makeItem(name: "b", category: "Еда", createdAt: .now)
        var filters = WarehouseFilters.none
        filters.selectedCategories = [" напитки "]
        let out = engine.apply(filters: filters, to: [a, b])
        #expect(out.map(\.name) == ["a"])
    }

    @Test
    func expirationFilter_expiredExcludesFutureDated() {
        let past = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let future = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        let expiredItem = makeItem(
            name: "старый",
            category: "c",
            createdAt: .now,
            expirationDate: past
        )
        let freshItem = makeItem(
            name: "свежий",
            category: "c",
            createdAt: .now,
            expirationDate: future
        )
        var filters = WarehouseFilters.none
        filters.expirationSet = [.expired]
        let out = engine.apply(filters: filters, to: [expiredItem, freshItem])
        #expect(Set(out.map(\.name)) == ["старый"])
    }

    @Test
    func smartFilter_noPhoto_excludesItemsWithImage() {
        let noPhoto = makeItem(name: "без", category: "c", createdAt: .now, imageURL: nil)
        let url = URL(string: "https://example.com/a.jpg")!
        let withPhoto = makeItem(name: "с", category: "c", createdAt: .now, imageURL: url)
        var filters = WarehouseFilters.none
        filters.smartFilters = [.noPhoto]
        let out = engine.apply(filters: filters, to: [noPhoto, withPhoto])
        #expect(out.map(\.name) == ["без"])
    }

    private func makeItem(
        name: String,
        category: String,
        createdAt: Date,
        expirationDate: Date? = nil,
        imageURL: URL? = nil
    ) -> Item {
        Item(
            name: name,
            categoryName: category,
            quantity: 1,
            expirationDate: expirationDate,
            imageURL: imageURL,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
