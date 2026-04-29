//
// OrganizationEntity.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

struct OrganizationMemberRow: Identifiable, Hashable {
    let member: OrganizationMember
    let isCurrentUser: Bool

    var id: UUID { member.userID }
}

struct LeaveConfirmation: Identifiable, Hashable {
    let id = UUID()
    let organization: Organization
}

struct DeleteOrgConfirmation: Identifiable, Hashable {
    let id = UUID()
    let organization: Organization
}
