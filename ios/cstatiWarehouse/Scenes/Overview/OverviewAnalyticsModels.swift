//
//  OverviewAnalyticsModels.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

struct OverviewAnalyticsSnapshot: Equatable, Codable {
    let organizationTitle: String
    let categoryRows: [OverviewCategoryRow]
    let shelfRiskRows: [OverviewShelfRiskRow]
}

struct OverviewCategoryRow: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let title: String
    /// Совпадает с `Item.categoryName` (пустая строка для позиций без категории).
    let filterKey: String
    let totalUnits: Int
    let canNavigateToWarehouse: Bool
}

struct OverviewShelfRiskRow: Identifiable, Equatable, Hashable, Codable {
    let band: ShelfRiskBand
    let lineCount: Int

    var id: ShelfRiskBand { band }

    private enum CodingKeys: String, CodingKey {
        case band
        case lineCount
    }

    init(band: ShelfRiskBand, lineCount: Int) {
        self.band = band
        self.lineCount = lineCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        band = try container.decode(ShelfRiskBand.self, forKey: .band)
        lineCount = try container.decode(Int.self, forKey: .lineCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(band, forKey: .band)
        try container.encode(lineCount, forKey: .lineCount)
    }
}

enum ShelfRiskBand: String, CaseIterable, Identifiable, Hashable, Codable {
    case expired
    case withinWeek
    case withinMonth
    case safeOrNoShelf

    var id: String { rawValue }

    /// Полная подпись для списка и подсказок.
    var title: String {
        switch self {
        case .expired:
            return "Просрочено"
        case .withinWeek:
            return "Истекает в течение 7 дней"
        case .withinMonth:
            return "Истекает через 8–30 дней"
        case .safeOrNoShelf:
            return "Свыше 30 дней или без срока"
        }
    }

    /// Короткая подпись для оси графика.
    var chartAxisLabel: String {
        switch self {
        case .expired:
            return "Просрочено"
        case .withinWeek:
            return "≤ 7 дн."
        case .withinMonth:
            return "8–30 дн."
        case .safeOrNoShelf:
            return "> 30 / нет"
        }
    }
}
