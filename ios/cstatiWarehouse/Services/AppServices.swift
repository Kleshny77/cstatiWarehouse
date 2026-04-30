//
//  AppServices.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

enum AppServices {
    static let sessionStorage: UserSessionStorageProtocol = PersistentUserSessionStorage()

    static let activeOrganizationStorage: ActiveOrganizationStorageProtocol = UserDefaultsActiveOrganizationStorage()

    static let offlineCache: OfflineCacheStoreProtocol = SwiftDataOfflineCacheStore()

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

    static func eventsService() -> EventsServiceProtocol {
        ApiEventsService(client: apiClient)
    }

    static func orgCategoriesService() -> OrgCategoriesServiceProtocol {
        ApiOrgCategoriesService(client: apiClient)
    }

    static func activityService() -> ActivityServiceProtocol {
        ApiActivityService(client: apiClient)
    }

    static func analyticsService() -> AnalyticsServiceProtocol {
        ApiAnalyticsService(apiClient: apiClient)
    }

    static func notificationPreferencesService() -> NotificationPreferencesServiceProtocol {
        ApiNotificationPreferencesService(apiClient: apiClient)
    }

    static func commentsService() -> CommentsServiceProtocol {
        ApiCommentsService(apiClient: apiClient)
    }

    static func reservationsService() -> ReservationsServiceProtocol {
        ApiReservationsService(apiClient: apiClient)
    }

    static let shelfLifeNotifier: ShelfLifeNotificationServiceProtocol = ShelfLifeNotificationService()

    static let smartExpirationScheduler: SmartExpirationSchedulerProtocol = SmartExpirationScheduler()
    
    static let webSocketService: WebSocketService = WebSocketService(
        baseURL: AppEnvironment.backendBaseURL.absoluteString,
        sessionStorage: sessionStorage
    )
}
