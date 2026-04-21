//
// ApiOrganizationsService.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

/// Реализация OrganizationsServiceProtocol поверх REST API бэкенда.
final class ApiOrganizationsService: OrganizationsServiceProtocol {

    // MARK: Properties

    private let client: APIClient

    // MARK: Lifecycle

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Public Methods

    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations",
            method: .get
        ) { (result: Result<OrganizationsListDTO, APIError>) in
            switch result {
            case .success(let dto):
                let summaries = dto.organizations.compactMap { $0.toDomain() }
                completion(.success(summaries))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/\(id.uuidString.lowercased())",
            method: .get
        ) { (result: Result<OrganizationResponseDTO, APIError>) in
            completion(Self.mapSummary(result))
        }
    }

    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations",
            method: .post,
            body: CreateOrganizationRequestDTO(name: name)
        ) { (result: Result<OrganizationResponseDTO, APIError>) in
            completion(Self.mapSummary(result))
        }
    }

    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/\(id.uuidString.lowercased())",
            method: .patch,
            body: UpdateOrganizationRequestDTO(name: name)
        ) { (result: Result<OrganizationResponseDTO, APIError>) in
            completion(Self.mapSummary(result))
        }
    }

    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(id.uuidString.lowercased())",
            method: .delete
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/\(organizationID.uuidString.lowercased())/members",
            method: .get
        ) { (result: Result<MembersResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                let members = dto.members.compactMap { $0.toDomain(organizationID: organizationID) }
                completion(.success(members))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(id.uuidString.lowercased())/leave",
            method: .post
        ) { result in
            completion(Self.mapVoid(result))
        }
    }

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(organizationID.uuidString.lowercased())/members/\(userID.uuidString.lowercased())",
            method: .delete
        ) { result in
            completion(Self.mapVoid(result))
        }
    }

    func changeMemberRole(organizationID: UUID, userID: UUID, role: OrgRole, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(organizationID.uuidString.lowercased())/members/\(userID.uuidString.lowercased())",
            method: .patch,
            body: ChangeRoleRequestDTO(role: role.rawValue)
        ) { result in
            completion(Self.mapVoid(result))
        }
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(organizationID.uuidString.lowercased())/transfer",
            method: .post,
            body: TransferOwnershipRequestDTO(newOwnerId: newOwnerID.uuidString.lowercased())
        ) { result in
            completion(Self.mapVoid(result))
        }
    }

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/\(organizationID.uuidString.lowercased())/invites",
            method: .get
        ) { (result: Result<InvitesListDTO, APIError>) in
            switch result {
            case .success(let dto):
                let invites = dto.invites.compactMap { $0.toDomain() }
                completion(.success(invites))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?, completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/\(organizationID.uuidString.lowercased())/invites",
            method: .post,
            body: CreateInviteRequestDTO(expiresInDays: expiresInDays, maxUses: maxUses)
        ) { (result: Result<InviteResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                guard let invite = dto.invite.toDomain() else {
                    completion(.failure(.serverError("Некорректный ответ сервера")))
                    return
                }
                completion(.success(invite))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        client.requestVoid(
            path: "/organizations/\(organizationID.uuidString.lowercased())/invites/\(inviteID.uuidString.lowercased())",
            method: .delete
        ) { result in
            completion(Self.mapVoid(result))
        }
    }

    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        client.request(
            path: "/organizations/join",
            method: .post,
            body: JoinByCodeRequestDTO(code: code)
        ) { (result: Result<OrganizationResponseDTO, APIError>) in
            completion(Self.mapSummary(result))
        }
    }

    // MARK: Private Methods

    private static func mapVoid(_ result: Result<Void, APIError>) -> Result<Void, OrganizationsError> {
        switch result {
        case .success: return .success(())
        case .failure(let error): return .failure(mapError(error))
        }
    }

    private static func mapSummary(_ result: Result<OrganizationResponseDTO, APIError>) -> Result<OrganizationSummary, OrganizationsError> {
        switch result {
        case .success(let dto):
            guard let summary = dto.organization.toDomain() else {
                return .failure(.serverError("Некорректный ответ сервера"))
            }
            return .success(summary)
        case .failure(let error):
            return .failure(mapError(error))
        }
    }

    private static func mapError(_ error: APIError) -> OrganizationsError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message):
            switch code {
            case "not_found":
                return .notFound
            case "forbidden":
                return .forbidden
            case "validation_error":
                return .validationError(message ?? "Некорректные данные")
            case "invite_not_usable":
                return .inviteNotUsable
            case "already_member":
                return .alreadyMember
            case "owner_cannot_leave",
                 "personal_org_protected",
                 "invite_wrong_org",
                 "cannot_target_owner",
                 "cannot_target_self":
                return .conflict(message ?? "Операция недоступна")
            default:
                if status == 403 { return .forbidden }
                if status == 404 { return .notFound }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}

// MARK: - DTOs

private struct OrganizationsListDTO: Decodable {
    let organizations: [OrganizationDTO]
}

private struct OrganizationResponseDTO: Decodable {
    let organization: OrganizationDTO
}

private struct CreateOrganizationRequestDTO: Encodable {
    let name: String
}

private struct UpdateOrganizationRequestDTO: Encodable {
    let name: String?
}

private struct MembersResponseDTO: Decodable {
    let members: [MemberDTO]
}

private struct OrganizationDTO: Decodable {
    let id: String
    let name: String
    let ownerId: String
    let isPersonal: Bool
    let myRole: String
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> OrganizationSummary? {
        guard let uuid = UUID(uuidString: id), let ownerUUID = UUID(uuidString: ownerId) else { return nil }
        guard let role = OrgRole(rawValue: myRole) else { return nil }
        let org = Organization(
            id: uuid,
            name: name,
            ownerID: ownerUUID,
            isPersonal: isPersonal,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        return OrganizationSummary(organization: org, role: role)
    }
}

private struct MemberDTO: Decodable {
    let userId: String
    let role: String
    let joinedAt: Date
    let name: String?
    let lastName: String?
    let email: String?
    let avatarUrl: String?

    func toDomain(organizationID: UUID) -> OrganizationMember? {
        guard let userUUID = UUID(uuidString: userId) else { return nil }
        guard let role = OrgRole(rawValue: role) else { return nil }
        return OrganizationMember(
            userID: userUUID,
            organizationID: organizationID,
            role: role,
            joinedAt: joinedAt,
            name: name,
            lastName: lastName,
            email: email,
            avatarURL: avatarUrl.flatMap { URL(string: $0) }
        )
    }
}

private struct ChangeRoleRequestDTO: Encodable {
    let role: String
}

private struct TransferOwnershipRequestDTO: Encodable {
    let newOwnerId: String
}

private struct CreateInviteRequestDTO: Encodable {
    let expiresInDays: Int?
    let maxUses: Int?
}

private struct JoinByCodeRequestDTO: Encodable {
    let code: String
}

private struct InvitesListDTO: Decodable {
    let invites: [InviteDTO]
}

private struct InviteResponseDTO: Decodable {
    let invite: InviteDTO
}

private struct InviteDTO: Decodable {
    let id: String
    let organizationId: String
    let code: String
    let createdById: String
    let createdAt: Date
    let expiresAt: Date?
    let maxUses: Int?
    let usedCount: Int
    let revokedAt: Date?
    let isActive: Bool

    func toDomain() -> OrganizationInvite? {
        guard let id = UUID(uuidString: id),
              let orgID = UUID(uuidString: organizationId),
              let createdBy = UUID(uuidString: createdById) else { return nil }
        return OrganizationInvite(
            id: id,
            organizationID: orgID,
            code: code,
            createdByID: createdBy,
            createdAt: createdAt,
            expiresAt: expiresAt,
            maxUses: maxUses,
            usedCount: usedCount,
            revokedAt: revokedAt,
            isActive: isActive
        )
    }
}
