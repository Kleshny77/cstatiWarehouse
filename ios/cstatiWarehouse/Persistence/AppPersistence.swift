//
//  AppPersistence.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import SwiftData

enum AppPersistence {

    static let modelContainer: ModelContainer = {
        let schema = Schema([OfflineCacheEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("SwiftData ModelContainer: \(error)")
        }
    }()
}
