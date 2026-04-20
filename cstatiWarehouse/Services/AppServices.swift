//
//  AppServices.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// Композиционный корень приложения: общие singletons.
/// Assembly-и переключены на эти фабрики вместо Mock*.
/// Для SwiftUI previews и unit-тестов по-прежнему можно передавать Mock-сервисы явно.
enum AppServices {
    static let sessionStorage: UserSessionStorageProtocol = UserDefaultsUserSessionStorage()

    static let activeOrganizationStorage: ActiveOrganizationStorageProtocol = UserDefaultsActiveOrganizationStorage()

    static let apiClient: APIClient = APIClient(sessionStorage: sessionStorage)

    static func authService() -> AuthServiceProtocol {
        ApiAuthService(client: apiClient)
    }

    static func warehouseService() -> WarehouseServiceProtocol {
        ApiWarehouseService(client: apiClient)
    }

    static func uploadsService() -> UploadsServiceProtocol {
        ApiUploadsService(client: apiClient)
    }

    static func organizationsService() -> OrganizationsServiceProtocol {
        ApiOrganizationsService(client: apiClient)
    }
}
