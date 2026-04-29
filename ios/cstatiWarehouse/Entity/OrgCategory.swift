//
//  OrgCategory.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

struct OrgCategory: Identifiable, Hashable {
    let id: UUID
    let organizationID: UUID
    var name: String
    let createdByID: UUID
    let createdAt: Date
}
