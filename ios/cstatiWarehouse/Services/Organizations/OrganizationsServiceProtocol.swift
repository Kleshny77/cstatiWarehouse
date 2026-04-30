//
// OrganizationsServiceProtocol.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

enum OrganizationsError: Error {
    case notFound
    case forbidden
    case validationError(String)
    case conflict(String)
    case alreadyMember
    case inviteNotUsable
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .notFound:
            return "Организация не найдена"
        case .forbidden:
            return "Недостаточно прав"
        case .validationError(let text):
            return text
        case .conflict(let text):
            return text.isEmpty ? "Операция недоступна" : text
        case .alreadyMember:
            return "Вы уже участник этой организации"
        case .inviteNotUsable:
            return "Код приглашения больше не действителен"
        case .networkError:
            return "Ошибка сети. Проверьте подключение."
        case .serverError(let text):
            return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        }
    }
}

protocol OrganizationsServiceProtocol: AnyObject {
    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void)
    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void)
    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void)
    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void)
    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void)
    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void)
    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void)

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void)
    func changeMemberRole(organizationID: UUID, userID: UUID, role: OrgRole, completion: @escaping (Result<Void, OrganizationsError>) -> Void)
    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void)

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void)
    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?, completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void)
    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void)
    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void)
}
