//
// PreviewServices.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import Foundation

#if DEBUG

/// Централизованные mock-сервисы для SwiftUI Previews
/// Используйте эти сервисы вместо создания новых моков в каждом Preview
enum PreviewServices {
    
    // MARK: - Warehouse Service
    
    /// Mock warehouse service с предзаполненными данными
    static let warehouse: WarehouseServiceProtocol = {
        let mock = MockWarehouseService.shared
        return mock
    }()
    
    // MARK: - Auth Service
    
    /// Mock auth service для preview
    static let auth: AuthServiceProtocol = MockAuthService()
    
    // MARK: - Organizations Service
    
    /// Mock organizations service для preview
    static let organizations: OrganizationsServiceProtocol = MockOrganizationsService()
    
    // MARK: - Events Service
    
    /// Mock events service для preview
    static let events: EventsServiceProtocol = MockEventsService()
    
    // MARK: - Categories Service
    
    /// Mock categories service для preview
    static let categories: OrgCategoriesServiceProtocol = MockCategoriesService()
    
    // MARK: - AppServices Bundle
    
    /// Полный набор mock-сервисов для preview
    static let appServices: AppServices = {
        AppServices(
            warehouseService: warehouse,
            authService: auth,
            organizationsService: organizations,
            eventsService: events,
            categoriesService: categories,
            sessionStorage: PreviewSessionStorage(),
            cacheStore: PreviewCacheStore(),
            activeOrgStorage: PreviewActiveOrgStorage()
        )
    }()
}

// MARK: - Mock Implementations

/// Mock Organizations Service
private final class MockOrganizationsService: OrganizationsServiceProtocol {
    func fetchOrganizations(completion: @escaping (Result<[Organization], OrganizationError>) -> Void) {
        let org = Organization(
            id: UUID(),
            name: "Preview Organization",
            createdAt: Date(),
            role: "admin"
        )
        completion(.success([org]))
    }
    
    func createOrganization(name: String, completion: @escaping (Result<Organization, OrganizationError>) -> Void) {
        let org = Organization(
            id: UUID(),
            name: name,
            createdAt: Date(),
            role: "admin"
        )
        completion(.success(org))
    }
    
    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationError>) -> Void) {
        completion(.success([]))
    }
    
    func createInvite(organizationID: UUID, role: String, completion: @escaping (Result<OrganizationInvite, OrganizationError>) -> Void) {
        let invite = OrganizationInvite(
            id: UUID(),
            organizationID: organizationID,
            code: "PREVIEW",
            role: role,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
        completion(.success(invite))
    }
    
    func acceptInvite(code: String, completion: @escaping (Result<Organization, OrganizationError>) -> Void) {
        let org = Organization(
            id: UUID(),
            name: "Joined Organization",
            createdAt: Date(),
            role: "member"
        )
        completion(.success(org))
    }
}

/// Mock Events Service
private final class MockEventsService: EventsServiceProtocol {
    func fetchEvents(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void) {
        completion(.success([]))
    }
    
    func createEvent(organizationID: UUID, name: String, date: Date, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        let event = OrgEvent(
            id: UUID(),
            organizationID: organizationID,
            name: name,
            eventDate: date,
            createdAt: Date()
        )
        completion(.success(event))
    }
}

/// Mock Categories Service
private final class MockCategoriesService: OrgCategoriesServiceProtocol {
    func fetchCategories(organizationID: UUID, completion: @escaping (Result<[String], CategoriesError>) -> Void) {
        completion(.success(["Напитки", "Еда", "Инвентарь"]))
    }
}

/// Mock Session Storage
private final class PreviewSessionStorage: UserSessionStorageProtocol {
    var user: User? = User(
        id: UUID(),
        email: "preview@example.com",
        name: "Preview User",
        createdAt: Date()
    )
    
    var accessToken: String? = "preview_access_token"
    var refreshToken: String? = "preview_refresh_token"
    
    func save(user: User, accessToken: String, refreshToken: String) {}
    func clear() {}
}

/// Mock Cache Store
private final class PreviewCacheStore: OfflineCacheStoreProtocol {
    func saveItems(_ items: [Item], for organizationID: UUID) {}
    func loadItems(for organizationID: UUID) -> [Item]? { nil }
    func clearItems(for organizationID: UUID) {}
    func clearAll() {}
}

/// Mock Active Organization Storage
private final class PreviewActiveOrgStorage: ActiveOrganizationStorage {
    override init() {
        super.init()
        self.activeOrganizationID = UUID()
    }
}

#endif
