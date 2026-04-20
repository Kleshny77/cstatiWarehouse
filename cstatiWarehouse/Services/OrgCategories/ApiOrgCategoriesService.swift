//
//  ApiOrgCategoriesService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class ApiOrgCategoriesService: OrgCategoriesServiceProtocol {

    // MARK: Properties

    private let client: APIClient

    // MARK: Lifecycle

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Public Methods

    func list(organizationID: UUID, completion: @escaping (Result<[OrgCategory], OrgCategoriesError>) -> Void) {
        let query = [URLQueryItem(name: "organizationId", value: organizationID.uuidString.lowercased())]
        client.request(
            path: "/org-categories",
            method: .get,
            query: query
        ) { (result: Result<CategoriesListDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.categories.compactMap { $0.toDomain() }))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func create(organizationID: UUID, name: String, completion: @escaping (Result<OrgCategory, OrgCategoriesError>) -> Void) {
        let body = CreateCategoryRequestDTO(
            organizationId: organizationID.uuidString.lowercased(),
            name: name
        )
        client.request(
            path: "/org-categories",
            method: .post,
            body: body
        ) { (result: Result<CategoryResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                guard let cat = dto.category.toDomain() else {
                    completion(.failure(.serverError("Некорректный ответ сервера")))
                    return
                }
                completion(.success(cat))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, OrgCategoriesError>) -> Void) {
        client.requestVoid(
            path: "/org-categories/\(id.uuidString.lowercased())",
            method: .delete
        ) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let error): completion(.failure(Self.mapError(error)))
            }
        }
    }

    // MARK: Private Methods

    private static func mapError(_ error: APIError) -> OrgCategoriesError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message):
            switch code {
            case "not_found": return .notFound
            case "forbidden": return .forbidden
            case "conflict": return .conflict(message ?? "")
            case "validation_error": return .validationError(message ?? "Некорректные данные")
            default:
                if status == 403 { return .forbidden }
                if status == 404 { return .notFound }
                if status == 409 { return .conflict(message ?? "") }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}

// MARK: - DTOs

private struct CategoriesListDTO: Decodable {
    let categories: [CategoryDTO]
}

private struct CategoryResponseDTO: Decodable {
    let category: CategoryDTO
}

private struct CreateCategoryRequestDTO: Encodable {
    let organizationId: String
    let name: String
}

private struct CategoryDTO: Decodable {
    let id: String
    let organizationId: String
    let createdById: String
    let name: String
    let createdAt: Date

    func toDomain() -> OrgCategory? {
        guard let id = UUID(uuidString: id),
              let orgID = UUID(uuidString: organizationId),
              let createdBy = UUID(uuidString: createdById) else { return nil }
        return OrgCategory(
            id: id,
            organizationID: orgID,
            name: name,
            createdByID: createdBy,
            createdAt: createdAt
        )
    }
}
