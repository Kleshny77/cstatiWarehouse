//
//  SwiftDataOfflineCacheStore.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import SwiftData

final class SwiftDataOfflineCacheStore: OfflineCacheStoreProtocol {

    private let container: ModelContainer

    init(container: ModelContainer = AppPersistence.modelContainer) {
        self.container = container
    }

    func payload(forKey key: String) async -> Data? {
        await MainActor.run {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<OfflineCacheEntry>(
                predicate: #Predicate { $0.cacheKey == key }
            )
            guard let entry = try? context.fetch(descriptor).first else { return nil }
            return entry.payload
        }
    }

    func save(payload: Data, forKey key: String) async throws {
        try await MainActor.run {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<OfflineCacheEntry>(
                predicate: #Predicate { $0.cacheKey == key }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.payload = payload
                existing.updatedAt = Date()
            } else {
                context.insert(OfflineCacheEntry(cacheKey: key, payload: payload, updatedAt: Date()))
            }
            try context.save()
        }
    }
}
