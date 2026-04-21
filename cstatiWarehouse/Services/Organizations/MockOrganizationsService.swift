//
// MockOrganizationsService.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

final class MockOrganizationsService: OrganizationsServiceProtocol {
    static let shared = MockOrganizationsService()

    private let currentUserID: UUID
    private var orgs: [UUID: Organization]
    private var memberships: [UUID: OrgRole] = [:]
    private var allMembers: [UUID: [OrganizationMember]] = [:]
    private var invites: [UUID: [OrganizationInvite]] = [:]

    init(currentUserID: UUID = UUID()) {
        self.currentUserID = currentUserID
        let personal = Organization(
            id: UUID(),
            name: "Личный склад",
            ownerID: currentUserID,
            isPersonal: true,
            createdAt: .now,
            updatedAt: .now
        )
        self.orgs = [personal.id: personal]
        self.memberships = [personal.id: .owner]
        self.allMembers = [
            personal.id: [
                OrganizationMember(
                    userID: currentUserID,
                    organizationID: personal.id,
                    role: .owner,
                    joinedAt: .now,
                    name: nil,
                    lastName: nil,
                    email: nil,
                    avatarURL: nil
                )
            ]
        ]
    }

    // MARK: Public Methods

    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void) {
        respond {
            let summaries = self.orgs.values.compactMap { org -> OrganizationSummary? in
                guard let role = self.memberships[org.id] else { return nil }
                return OrganizationSummary(organization: org, role: role)
            }
            completion(.success(summaries.sorted { $0.organization.createdAt < $1.organization.createdAt }))
        }
    }

    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        respond {
            guard let org = self.orgs[id], let role = self.memberships[id] else {
                completion(.failure(.notFound))
                return
            }
            completion(.success(OrganizationSummary(organization: org, role: role)))
        }
    }

    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        respond {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                completion(.failure(.validationError("Введите название")))
                return
            }
            let org = Organization(
                id: UUID(),
                name: trimmed,
                ownerID: self.currentUserID,
                isPersonal: false,
                createdAt: .now,
                updatedAt: .now
            )
            self.orgs[org.id] = org
            self.memberships[org.id] = .owner
            self.allMembers[org.id] = [
                OrganizationMember(
                    userID: self.currentUserID,
                    organizationID: org.id,
                    role: .owner,
                    joinedAt: .now,
                    name: nil,
                    lastName: nil,
                    email: nil,
                    avatarURL: nil
                )
            ]
            completion(.success(OrganizationSummary(organization: org, role: .owner)))
        }
    }

    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        respond {
            guard var org = self.orgs[id], let role = self.memberships[id] else {
                completion(.failure(.notFound))
                return
            }
            guard role.canEditOrganization else {
                completion(.failure(.forbidden))
                return
            }
            if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                org.name = name
                org.updatedAt = .now
                self.orgs[id] = org
            }
            completion(.success(OrganizationSummary(organization: org, role: role)))
        }
    }

    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            guard let org = self.orgs[id] else {
                completion(.failure(.notFound))
                return
            }
            if org.isPersonal {
                completion(.failure(.conflict("Персональную организацию удалить нельзя")))
                return
            }
            self.orgs.removeValue(forKey: id)
            self.memberships.removeValue(forKey: id)
            self.allMembers.removeValue(forKey: id)
            completion(.success(()))
        }
    }

    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void) {
        respond {
            guard self.memberships[organizationID] != nil else {
                completion(.failure(.notFound))
                return
            }
            completion(.success(self.allMembers[organizationID] ?? []))
        }
    }

    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            guard let role = self.memberships[id] else {
                completion(.failure(.notFound))
                return
            }
            if role == .owner {
                completion(.failure(.conflict("Владелец не может выйти из организации")))
                return
            }
            self.memberships.removeValue(forKey: id)
            self.allMembers[id]?.removeAll { $0.userID == self.currentUserID }
            completion(.success(()))
        }
    }

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            guard let role = self.memberships[organizationID], role.canManageMembers else {
                completion(.failure(.forbidden))
                return
            }
            self.allMembers[organizationID]?.removeAll { $0.userID == userID }
            completion(.success(()))
        }
    }

    func changeMemberRole(organizationID: UUID, userID: UUID, role: OrgRole, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            guard self.memberships[organizationID] == .owner else {
                completion(.failure(.forbidden))
                return
            }
            self.allMembers[organizationID] = self.allMembers[organizationID]?.map { m in
                var copy = m
                if m.userID == userID { copy.role = role }
                return copy
            }
            completion(.success(()))
        }
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            guard self.memberships[organizationID] == .owner else {
                completion(.failure(.forbidden))
                return
            }
            self.memberships[organizationID] = .admin
            completion(.success(()))
        }
    }

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void) {
        respond {
            guard let role = self.memberships[organizationID], role.canManageMembers else {
                completion(.failure(.forbidden))
                return
            }
            completion(.success(self.invites[organizationID] ?? []))
        }
    }

    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?, completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void) {
        respond {
            guard let role = self.memberships[organizationID], role.canManageMembers else {
                completion(.failure(.forbidden))
                return
            }
            let invite = OrganizationInvite(
                id: UUID(),
                organizationID: organizationID,
                code: Self.mockInviteCode(),
                createdByID: self.currentUserID,
                createdAt: .now,
                expiresAt: expiresInDays.map { Date().addingTimeInterval(TimeInterval($0) * 86_400) },
                maxUses: maxUses,
                usedCount: 0,
                revokedAt: nil,
                isActive: true
            )
            self.invites[organizationID, default: []].append(invite)
            completion(.success(invite))
        }
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        respond {
            self.invites[organizationID] = self.invites[organizationID]?.map { inv in
                guard inv.id == inviteID else { return inv }
                return OrganizationInvite(
                    id: inv.id,
                    organizationID: inv.organizationID,
                    code: inv.code,
                    createdByID: inv.createdByID,
                    createdAt: inv.createdAt,
                    expiresAt: inv.expiresAt,
                    maxUses: inv.maxUses,
                    usedCount: inv.usedCount,
                    revokedAt: .now,
                    isActive: false
                )
            }
            completion(.success(()))
        }
    }

    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        respond {
            completion(.failure(.notFound))
        }
    }

    // MARK: Private Methods

    /// Совпадает с бэкендом: `invitecode.DefaultLength` и алфавит без O/0/I/1.
    private static let mockInviteAlphabet: [Character] = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    private static func mockInviteCode() -> String {
        String((0..<20).map { _ in mockInviteAlphabet.randomElement()! })
    }

    private func respond(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
