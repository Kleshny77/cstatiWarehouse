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
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    // MARK: Private Methods

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
            case "already_member", "owner_cannot_leave", "cannot_delete_personal":
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

    func toDomain(organizationID: UUID) -> OrganizationMember? {
        guard let userUUID = UUID(uuidString: userId) else { return nil }
        guard let role = OrgRole(rawValue: role) else { return nil }
        return OrganizationMember(
            userID: userUUID,
            organizationID: organizationID,
            role: role,
            joinedAt: joinedAt,
            name: nil,
            email: nil,
            avatarURL: nil
        )
    }
}
