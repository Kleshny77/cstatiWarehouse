//
//  AnalyticsServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum AnalyticsError: Error {
    case networkError(Error)
    case decodingError
    case unauthorized
    case notFound
    case serverError
    case unknown
    
    var message: String {
        switch self {
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .decodingError:
            return "Ошибка обработки данных"
        case .unauthorized:
            return "Требуется авторизация"
        case .notFound:
            return "Данные не найдены"
        case .serverError:
            return "Ошибка сервера"
        case .unknown:
            return "Неизвестная ошибка"
        }
    }
}

struct DashboardMetrics {
    let totalItems: Int
    let inStockItems: Int
    let archivedItems: Int
    let expiringSoon: Int
    let categoriesCount: Int
    let stockTrend: [StockDataPoint]
    let categoryDistribution: [CategoryDistribution]
    let expiringItems: [ExpiringItem]
}

struct StockDataPoint: Identifiable, Codable {
    let date: Date
    let quantity: Int

    var id: Date { date }

    enum CodingKeys: String, CodingKey {
        case date, quantity
    }
}

struct CategoryDistribution: Identifiable, Codable {
    let categoryName: String
    let count: Int

    var id: String { categoryName }

    enum CodingKeys: String, CodingKey {
        case categoryName, count
    }
}

struct ExpiringItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let quantity: Int
    let expirationDate: Date
    let daysUntil: Int

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, expirationDate, daysUntil
    }
}

protocol AnalyticsServiceProtocol: AnyObject {
    func fetchDashboardMetrics(
        organizationID: UUID,
        completion: @escaping (Result<DashboardMetrics, AnalyticsError>) -> Void
    )
}
