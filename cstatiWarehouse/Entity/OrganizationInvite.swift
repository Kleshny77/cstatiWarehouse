//
// OrganizationInvite.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

/// Многоразовое приглашение в организацию. Выдаётся owner/admin, раздаётся кодом.
struct OrganizationInvite: Identifiable, Hashable, Codable {
    let id: UUID
    let organizationID: UUID
    let code: String
    let createdByID: UUID
    let createdAt: Date
    let expiresAt: Date?
    let maxUses: Int?
    let usedCount: Int
    let revokedAt: Date?
    let isActive: Bool
}
