//
//  ActivityEntry.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

struct ActivityEntry: Identifiable, Hashable {
    let id: UUID
    let organizationID: UUID
    let actorUserID: UUID
    let actorDisplayName: String
    let kind: String
    let targetType: String
    let targetID: UUID?
    let summary: String
    let createdAt: Date
}
