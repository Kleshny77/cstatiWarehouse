//
//  OfflineMutationQueueTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct OfflineMutationQueueTests {
    @Test
    func enqueue_processesCreateItem_andClearsQueue() async {
        let orgID = MockWarehouseService.defaultOrganizationID
        let warehouse = MockWarehouseService(seed: [])
        let cache = OfflineCacheNoop()
        let sut = OfflineMutationQueue(
            warehouseService: warehouse,
            storage: cache,
            maxRetries: 2,
            retryDelay: 0.05
        )

        let item = Item(name: "Новое", categoryName: "кат", quantity: 1)
        sut.enqueue(.createItem(item, organizationID: orgID))

        await waitUntil { sut.pendingCount == 0 }

        #expect(sut.pendingCount == 0)
        let listed = await fetchActive(warehouse: warehouse, orgID: orgID)
        #expect(listed.count == 1)
        #expect(listed.first?.name == "Новое")
    }

    private func fetchActive(warehouse: MockWarehouseService, orgID: UUID) async -> [Item] {
        await withCheckedContinuation { continuation in
            warehouse.fetchActiveItems(organizationID: orgID, scope: .all) { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<80 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

private final class OfflineCacheNoop: OfflineCacheStoreProtocol {
    func payload(forKey key: String) async -> Data? { nil }
    func save(payload: Data, forKey key: String) async throws {}
}
