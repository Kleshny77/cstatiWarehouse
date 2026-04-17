//
//  MockWarehouseServiceTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct MockWarehouseServiceTests {
    @Test
    func fetchActiveItems_returnsOnlyInStock_sortedByCreatedAtDesc() async {
        let now = Date.now
        let older = now.addingTimeInterval(-1000)
        let newer = now.addingTimeInterval(-100)
        let archivedItem = makeItem(name: "archived", createdAt: now, status: .archived(reason: .disposed, at: now))
        let olderItem = makeItem(name: "older", createdAt: older)
        let newerItem = makeItem(name: "newer", createdAt: newer)
        let service = MockWarehouseService(seed: [archivedItem, olderItem, newerItem])
        
        let result = await run { service.fetchActiveItems(completion: $0) }
        let items = try! result.get()
        
        #expect(items.count == 2)
        #expect(items.first?.name == "newer")
        #expect(items.last?.name == "older")
    }
    
    @Test
    func fetchHistory_returnsOnlyArchived_sortedByArchivedAtDesc() async {
        let now = Date.now
        let olderArchive = now.addingTimeInterval(-500)
        let newerArchive = now.addingTimeInterval(-50)
        let active = makeItem(name: "active", createdAt: now)
        let olderArchived = makeItem(
            name: "old-archive",
            createdAt: now,
            status: .archived(reason: .disposed, at: olderArchive)
        )
        let newerArchived = makeItem(
            name: "new-archive",
            createdAt: now,
            status: .archived(reason: .usedAtEvent, at: newerArchive)
        )
        let service = MockWarehouseService(seed: [active, olderArchived, newerArchived])
        
        let result = await run { service.fetchHistory(completion: $0) }
        let items = try! result.get()
        
        #expect(items.map(\.name) == ["new-archive", "old-archive"])
    }
    
    @Test
    func createItem_addsToActiveList() async {
        let service = MockWarehouseService(seed: [])
        let item = makeItem(name: "new")
        
        _ = await run { service.createItem(item, completion: $0) }
        let result = await run { service.fetchActiveItems(completion: $0) }
        
        #expect(try! result.get().map(\.id) == [item.id])
    }
    
    @Test
    func updateItem_succeeds_whenItemExists() async {
        let original = makeItem(name: "original")
        let service = MockWarehouseService(seed: [original])
        var updated = original
        updated.name = "edited"
        
        let updateResult = await run { service.updateItem(updated, completion: $0) }
        #expect((try? updateResult.get())?.name == "edited")
        
        let fetch = await run { service.fetchActiveItems(completion: $0) }
        #expect(try! fetch.get().first?.name == "edited")
    }
    
    @Test
    func updateItem_failsWithNotFound_whenMissing() async {
        let service = MockWarehouseService(seed: [])
        let ghost = makeItem(name: "ghost")
        
        let result = await run { service.updateItem(ghost, completion: $0) }
        
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let error):
            if case .notFound = error { return }
            Issue.record("Expected .notFound, got \(error)")
        }
    }
    
    @Test
    func archiveItem_movesItemFromActiveToHistory() async {
        let item = makeItem(name: "used")
        let service = MockWarehouseService(seed: [item])
        let at = Date.now
        
        let archived = await run { service.archiveItem(id: item.id, reason: .usedAtEvent, at: at, completion: $0) }
        let saved = try! archived.get()
        guard case .archived(let reason, let savedAt) = saved.status else {
            Issue.record("Expected archived status, got \(saved.status)")
            return
        }
        #expect(reason == .usedAtEvent)
        #expect(savedAt == at)
        
        let active = await run { service.fetchActiveItems(completion: $0) }
        #expect(try! active.get().isEmpty)
        
        let history = await run { service.fetchHistory(completion: $0) }
        #expect(try! history.get().map(\.id) == [item.id])
    }
    
    @Test
    func archiveItem_failsWithNotFound_whenMissing() async {
        let service = MockWarehouseService(seed: [])
        let result = await run { service.archiveItem(id: UUID(), reason: .other, at: .now, completion: $0) }
        
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let error):
            if case .notFound = error { return }
            Issue.record("Expected .notFound, got \(error)")
        }
    }
    
    @Test
    func deleteItem_removesItemFromBothLists() async {
        let item = makeItem(name: "gone")
        let service = MockWarehouseService(seed: [item])
        
        let deleteResult = await run { service.deleteItem(id: item.id, completion: $0) }
        _ = try! deleteResult.get()
        
        let active = await run { service.fetchActiveItems(completion: $0) }
        let history = await run { service.fetchHistory(completion: $0) }
        #expect(try! active.get().isEmpty)
        #expect(try! history.get().isEmpty)
    }
    
    @Test
    func deleteItem_failsWithNotFound_whenMissing() async {
        let service = MockWarehouseService(seed: [])
        let result = await run { service.deleteItem(id: UUID(), completion: $0) }
        
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let error):
            if case .notFound = error { return }
            Issue.record("Expected .notFound, got \(error)")
        }
    }
    
    // MARK: Helpers
    
    private func makeItem(
        name: String,
        createdAt: Date = .now,
        status: ItemStatus = .inStock
    ) -> Item {
        Item(
            name: name,
            categoryName: "cat",
            quantity: 1,
            createdAt: createdAt,
            status: status
        )
    }
    
    private func run<T>(_ operation: @escaping (@escaping (Result<T, WarehouseError>) -> Void) -> Void) async -> Result<T, WarehouseError> {
        await withCheckedContinuation { continuation in
            operation { continuation.resume(returning: $0) }
        }
    }
}
