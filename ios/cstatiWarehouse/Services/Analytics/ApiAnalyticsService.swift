//
//  ApiAnalyticsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

final class ApiAnalyticsService: AnalyticsServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func fetchDashboardMetrics(
        organizationID: UUID,
        completion: @escaping (Result<DashboardMetrics, AnalyticsError>) -> Void
    ) {
        let endpoint = "/analytics/dashboard"
        let query = [URLQueryItem(name: "organization_id", value: organizationID.uuidString)]

        apiClient.request(
            path: endpoint,
            method: .get,
            query: query,
            body: nil as String?,
            authenticated: true
        ) { (result: Result<DashboardMetricsDTO, APIError>) in
            switch result {
            case .success(let dto):
                guard let metrics = dto.toDomain() else {
                    completion(.failure(.decodingError))
                    return
                }
                completion(.success(metrics))
                
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }
    
    private static func mapError(_ error: APIError) -> AnalyticsError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .server(let status, _, _, _):
            if status == 404 { return .notFound }
            return .serverError
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .decodingError
        }
    }
}

// MARK: - DTOs

private struct DashboardMetricsDTO: Decodable {
    let totalItems: Int
    let inStockItems: Int
    let archivedItems: Int
    let expiringSoon: Int
    let categoriesCount: Int
    let stockTrend: [StockDataPointDTO]
    let categoryDistribution: [CategoryDistributionDTO]
    let expiringItems: [ExpiringItemDTO]

    func toDomain() -> DashboardMetrics? {
        let stockTrendDomain = stockTrend.map { dto in
            StockDataPoint(date: dto.date, quantity: dto.quantity)
        }
        
        let categoryDistDomain = categoryDistribution.map { dto in
            CategoryDistribution(categoryName: dto.categoryName, count: dto.count)
        }
        
        let expiringItemsDomain = expiringItems.compactMap { dto -> ExpiringItem? in
            guard let id = UUID(uuidString: dto.id) else { return nil }
            return ExpiringItem(
                id: id,
                name: dto.name,
                quantity: dto.quantity,
                expirationDate: dto.expirationDate,
                daysUntil: dto.daysUntil
            )
        }
        
        return DashboardMetrics(
            totalItems: totalItems,
            inStockItems: inStockItems,
            archivedItems: archivedItems,
            expiringSoon: expiringSoon,
            categoriesCount: categoriesCount,
            stockTrend: stockTrendDomain,
            categoryDistribution: categoryDistDomain,
            expiringItems: expiringItemsDomain
        )
    }
}

private struct StockDataPointDTO: Decodable {
    let date: Date
    let quantity: Int
}

private struct CategoryDistributionDTO: Decodable {
    let categoryName: String
    let count: Int
}

private struct ExpiringItemDTO: Decodable {
    let id: String
    let name: String
    let quantity: Int
    let expirationDate: Date
    let daysUntil: Int
}
