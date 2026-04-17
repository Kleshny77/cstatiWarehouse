//
//  ItemTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct ItemTests {
    private static let reference: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 17
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }()
    
    @Test
    func expirationStatus_noDate_returnsNoShelfLife() {
        let item = makeItem(expirationDate: nil)
        #expect(item.expirationStatus(referenceNow: Self.reference) == .noShelfLife)
    }
    
    @Test
    func expirationStatus_pastDate_returnsExpired() {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Self.reference)!
        let item = makeItem(expirationDate: past)
        #expect(item.expirationStatus(referenceNow: Self.reference) == .expired)
    }
    
    @Test
    func expirationStatus_today_returnsExpiringSoon() {
        let item = makeItem(expirationDate: Self.reference)
        let status = item.expirationStatus(referenceNow: Self.reference)
        guard case .expiringSoon = status else {
            Issue.record("Expected .expiringSoon, got \(status)")
            return
        }
    }
    
    @Test
    func expirationStatus_in10Days_returnsExpiringSoon() {
        let date = Calendar.current.date(byAdding: .day, value: 10, to: Self.reference)!
        let item = makeItem(expirationDate: date)
        let status = item.expirationStatus(referenceNow: Self.reference)
        guard case .expiringSoon(let expiresAt) = status else {
            Issue.record("Expected .expiringSoon, got \(status)")
            return
        }
        #expect(Calendar.current.isDate(expiresAt, inSameDayAs: date))
    }
    
    @Test
    func expirationStatus_in60Days_returnsOk() {
        let date = Calendar.current.date(byAdding: .day, value: 60, to: Self.reference)!
        let item = makeItem(expirationDate: date)
        let status = item.expirationStatus(referenceNow: Self.reference)
        guard case .ok(let expiresAt) = status else {
            Issue.record("Expected .ok, got \(status)")
            return
        }
        #expect(Calendar.current.isDate(expiresAt, inSameDayAs: date))
    }
    
    @Test
    func itemStatus_isArchived() {
        let inStock: ItemStatus = .inStock
        let archived: ItemStatus = .archived(reason: .usedAtEvent, at: .now)
        #expect(inStock.isArchived == false)
        #expect(archived.isArchived == true)
    }
    
    @Test
    func archiveReason_hasStableId() {
        for reason in ArchiveReason.allCases {
            #expect(reason.id == reason.rawValue)
            #expect(!reason.title.isEmpty)
            #expect(!reason.icon.isEmpty)
        }
    }
    
    // MARK: Helpers
    
    private func makeItem(expirationDate: Date?) -> Item {
        Item(
            name: "Тест",
            categoryName: "тестовая категория",
            expirationDate: expirationDate
        )
    }
}
