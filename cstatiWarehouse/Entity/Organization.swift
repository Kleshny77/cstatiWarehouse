//
// Organization.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

// MARK: - OrgRole

enum OrgRole: String, Codable, Hashable, CaseIterable {
    case owner
    case admin
    case member

    var title: String {
        switch self {
        case .owner: return "Владелец"
        case .admin: return "Админ"
        case .member: return "Участник"
        }
    }

    var canManageMembers: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }

    var canEditOrganization: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }
}

// MARK: - Organization

struct Organization: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    let ownerID: UUID
    let isPersonal: Bool
    let createdAt: Date
    var updatedAt: Date
}

// MARK: - OrganizationMember

struct OrganizationMember: Identifiable, Hashable, Codable {
    var id: UUID { userID }
    let userID: UUID
    let organizationID: UUID
    var role: OrgRole
    let joinedAt: Date
    let name: String?
    let email: String?
    let avatarURL: URL?
}

// MARK: - OrganizationSummary

/// Организация с ролью текущего пользователя — то, что возвращает `/organizations`.
struct OrganizationSummary: Identifiable, Hashable, Codable {
    var id: UUID { organization.id }
    let organization: Organization
    let role: OrgRole
}
