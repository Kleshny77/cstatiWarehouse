//
//  OfflineCacheKeys.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum OfflineCacheKeys {

    static func warehouseActiveItems(organizationID: UUID, scope: WarehouseScope) -> String {
        "warehouse.activeItems.\(organizationID.uuidString.lowercased()).\(scope.rawValue)"
    }

    static func overviewAnalytics(organizationID: UUID) -> String {
        "overview.analytics.\(organizationID.uuidString.lowercased())"
    }
    
    static let offlineMutationQueue = "offline.mutationQueue"
}
