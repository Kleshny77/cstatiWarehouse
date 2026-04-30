//
//  OrgEvent.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

struct OrgEvent: Identifiable, Hashable {
    let id: UUID
    let organizationID: UUID
    var name: String
    var description: String
    var startsAt: Date?
    let createdByID: UUID
    let createdAt: Date
    var updatedAt: Date
}
