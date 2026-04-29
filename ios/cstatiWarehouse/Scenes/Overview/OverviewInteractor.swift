//
//  OverviewInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol OverviewInteractorInputProtocol: AnyObject {
    func loadAnalytics()
}

protocol OverviewInteractorOutputProtocol: AnyObject {
    func noActiveOrganization()
    func analyticsLoaded(_ snapshot: OverviewAnalyticsSnapshot)
    func loadFailed(message: String)
}

final class OverviewInteractor: OverviewInteractorInputProtocol {

    weak var presenter: OverviewInteractorOutputProtocol?

    private let organizationsService: OrganizationsServiceProtocol
    private let warehouseService: WarehouseServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol
    private let offlineCache: OfflineCacheStoreProtocol

    init(
        organizationsService: OrganizationsServiceProtocol,
        warehouseService: WarehouseServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol,
        offlineCache: OfflineCacheStoreProtocol = AppServices.offlineCache
    ) {
        self.organizationsService = organizationsService
        self.warehouseService = warehouseService
        self.activeOrgStorage = activeOrgStorage
        self.offlineCache = offlineCache
    }

    func loadAnalytics() {
        guard let organizationID = activeOrgStorage.activeOrganizationID else {
            presenter?.noActiveOrganization()
            return
        }

        let cacheKey = OfflineCacheKeys.overviewAnalytics(organizationID: organizationID)
        Task { [weak self] in
            guard let self else { return }
            if let data = await self.offlineCache.payload(forKey: cacheKey),
               let snapshot = try? JSONDecoder().decode(OverviewAnalyticsSnapshot.self, from: data) {
                await MainActor.run {
                    self.presenter?.analyticsLoaded(snapshot)
                }
            }

            self.organizationsService.fetchOrganization(id: organizationID) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.presenter?.loadFailed(message: error.message)
                    }
                case .success(let summary):
                    let title = self.displayTitle(for: summary)
                    self.fetchWarehouse(organizationID: organizationID, organizationTitle: title, cacheKey: cacheKey)
                }
            }
        }
    }

    private func fetchWarehouse(organizationID: UUID, organizationTitle: String, cacheKey: String) {
        warehouseService.fetchActiveItems(organizationID: organizationID, scope: .all) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.presenter?.loadFailed(message: error.message)
                }
            case .success(let items):
                let snapshot = OverviewAnalyticsBuilder.makeSnapshot(
                    organizationTitle: organizationTitle,
                    items: items
                )
                Task {
                    if let payload = try? JSONEncoder().encode(snapshot) {
                        try? await self.offlineCache.save(payload: payload, forKey: cacheKey)
                    }
                }
                DispatchQueue.main.async {
                    self.presenter?.analyticsLoaded(snapshot)
                }
            }
        }
    }

    private func displayTitle(for summary: OrganizationSummary) -> String {
        if summary.organization.isPersonal {
            return "Мой склад"
        }
        let name = summary.organization.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Организация" : name
    }
}
