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
    func analyticsLoaded(
        _ metrics: DashboardMetrics,
        snapshot: OverviewAnalyticsSnapshot,
        organizationTitle: String
    )
    func analyticsCacheHit(_ metrics: DashboardMetrics, organizationTitle: String)
    func loadFailed(message: String)
}

final class OverviewInteractor: OverviewInteractorInputProtocol {

    weak var presenter: OverviewInteractorOutputProtocol?

    private let analyticsService: AnalyticsServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol
    private let warehouseService: WarehouseServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol
    private let offlineCache: OfflineCacheStoreProtocol

    init(
        analyticsService: AnalyticsServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        warehouseService: WarehouseServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol,
        offlineCache: OfflineCacheStoreProtocol = AppServices.offlineCache
    ) {
        self.analyticsService = analyticsService
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

        if shouldDeliverUITestStubOverview {
            deliverUITestStubOverview()
            return
        }

        let cacheKey = OfflineCacheKeys.overviewAnalytics(organizationID: organizationID)
        Task { [weak self] in
            guard let self else { return }
            
            if let cachedData = await self.offlineCache.payload(forKey: cacheKey),
               let cached = try? JSONDecoder().decode(CachedDashboardMetrics.self, from: cachedData) {
                await MainActor.run {
                    self.presenter?.analyticsCacheHit(cached.metrics, organizationTitle: cached.organizationTitle)
                }
            }
            
            await self.fetchFreshAnalytics(organizationID: organizationID, cacheKey: cacheKey)
        }
    }

    private var shouldDeliverUITestStubOverview: Bool {
        ProcessInfo.processInfo.arguments.contains(UITestingLaunchArgument.injectSession)
    }

    private func deliverUITestStubOverview() {
        let metrics = DashboardMetrics(
            totalItems: 0,
            inStockItems: 0,
            archivedItems: 0,
            expiringSoon: 0,
            categoriesCount: 0,
            stockTrend: [],
            categoryDistribution: [],
            expiringItems: []
        )
        let snapshot = OverviewAnalyticsBuilder.makeSnapshot(
            organizationTitle: "Тестовая организация",
            items: []
        )
        presenter?.analyticsLoaded(
            metrics,
            snapshot: snapshot,
            organizationTitle: "Тестовая организация"
        )
    }

    private func fetchFreshAnalytics(organizationID: UUID, cacheKey: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            organizationsService.fetchOrganization(id: organizationID) { [weak self] result in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.presenter?.loadFailed(message: error.message)
                    }
                    continuation.resume()
                    
                case .success(let summary):
                    let title = self.displayTitle(for: summary)

                    let group = DispatchGroup()
                    var metricsResult: Result<DashboardMetrics, AnalyticsError>?
                    var itemsResult: Result<[Item], WarehouseError>?

                    group.enter()
                    self.analyticsService.fetchDashboardMetrics(organizationID: organizationID) { result in
                        metricsResult = result
                        group.leave()
                    }

                    group.enter()
                    self.warehouseService.fetchActiveItems(organizationID: organizationID, scope: .all) { result in
                        itemsResult = result
                        group.leave()
                    }

                    group.notify(queue: .main) { [weak self] in
                        guard let self else {
                            continuation.resume()
                            return
                        }

                        let items: [Item]
                        switch itemsResult {
                        case .success(let list):
                            items = list
                        case .failure, .none:
                            items = []
                        }

                        let snapshot = OverviewAnalyticsBuilder.makeSnapshot(
                            organizationTitle: title,
                            items: items
                        )

                        switch metricsResult {
                        case .failure(let error):
                            self.presenter?.loadFailed(message: error.message)
                        case .success(let metrics):
                            let cached = CachedDashboardMetrics(
                                metrics: metrics,
                                organizationTitle: title
                            )
                            Task {
                                if let payload = try? JSONEncoder().encode(cached) {
                                    try? await self.offlineCache.save(payload: payload, forKey: cacheKey)
                                }
                            }
                            self.presenter?.analyticsLoaded(metrics, snapshot: snapshot, organizationTitle: title)
                        case .none:
                            self.presenter?.loadFailed(message: AnalyticsError.unknown.message)
                        }

                        continuation.resume()
                    }
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

// MARK: - Cache Model

private struct CachedDashboardMetrics: Codable {
    let metrics: DashboardMetrics
    let organizationTitle: String
}

extension DashboardMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case totalItems, inStockItems, archivedItems, expiringSoon, categoriesCount
        case stockTrend, categoryDistribution, expiringItems
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = try container.decode(Int.self, forKey: .totalItems)
        inStockItems = try container.decode(Int.self, forKey: .inStockItems)
        archivedItems = try container.decode(Int.self, forKey: .archivedItems)
        expiringSoon = try container.decode(Int.self, forKey: .expiringSoon)
        categoriesCount = try container.decode(Int.self, forKey: .categoriesCount)
        stockTrend = try container.decode([StockDataPoint].self, forKey: .stockTrend)
        categoryDistribution = try container.decode([CategoryDistribution].self, forKey: .categoryDistribution)
        expiringItems = try container.decode([ExpiringItem].self, forKey: .expiringItems)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalItems, forKey: .totalItems)
        try container.encode(inStockItems, forKey: .inStockItems)
        try container.encode(archivedItems, forKey: .archivedItems)
        try container.encode(expiringSoon, forKey: .expiringSoon)
        try container.encode(categoriesCount, forKey: .categoriesCount)
        try container.encode(stockTrend, forKey: .stockTrend)
        try container.encode(categoryDistribution, forKey: .categoryDistribution)
        try container.encode(expiringItems, forKey: .expiringItems)
    }
}
