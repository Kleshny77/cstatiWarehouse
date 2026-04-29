//
//  OverviewAnalyticsBuilder.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum OverviewAnalyticsBuilder {

    private static let topCategoryLimit = 7

    static func makeSnapshot(
        organizationTitle: String,
        items: [Item],
        now: Date = .now,
        calendar: Calendar? = nil
    ) -> OverviewAnalyticsSnapshot {
        var cal = calendar ?? Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")

        let categoryRows = categoryRows(from: items)
        let shelfRiskRows = shelfRiskRows(from: items, now: now, calendar: cal)

        return OverviewAnalyticsSnapshot(
            organizationTitle: organizationTitle,
            categoryRows: categoryRows,
            shelfRiskRows: shelfRiskRows
        )
    }

    static func categoryRows(from items: [Item]) -> [OverviewCategoryRow] {
        let roots = items.filter { $0.parentItemID == nil }
        var counts: [String: Int] = [:]
        for item in roots {
            let trimmed = item.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[trimmed, default: 0] += item.effectiveQuantityForSort
        }

        let mapped = counts.map { filterKey, value -> OverviewCategoryRow in
            let title = filterKey.isEmpty ? "Без категории" : filterKey
            return OverviewCategoryRow(
                id: title,
                title: title,
                filterKey: filterKey,
                totalUnits: value,
                canNavigateToWarehouse: true
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalUnits != rhs.totalUnits {
                return lhs.totalUnits > rhs.totalUnits
            }
            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }

        guard mapped.count > topCategoryLimit + 1 else {
            return mapped
        }

        let top = Array(mapped.prefix(topCategoryLimit))
        let restSum = mapped.dropFirst(topCategoryLimit).map(\.totalUnits).reduce(0, +)
        let other = OverviewCategoryRow(
            id: "overview.category.other",
            title: "Прочее",
            filterKey: "",
            totalUnits: restSum,
            canNavigateToWarehouse: false
        )
        return top + [other]
    }

    static func shelfRiskRows(from items: [Item], now: Date, calendar: Calendar) -> [OverviewShelfRiskRow] {
        let roots = items.filter { $0.parentItemID == nil }
        var buckets: [ShelfRiskBand: Int] = Dictionary(uniqueKeysWithValues: ShelfRiskBand.allCases.map { ($0, 0) })

        for root in roots {
            for line in stockLines(for: root) {
                let band = shelfBand(for: line, now: now, calendar: calendar)
                buckets[band, default: 0] += 1
            }
        }

        return ShelfRiskBand.allCases.map { band in
            OverviewShelfRiskRow(band: band, lineCount: buckets[band] ?? 0)
        }
    }

    static func stockLines(for root: Item) -> [Item] {
        if root.status.isArchived { return [] }
        if root.variants.isEmpty {
            return [root]
        }
        return root.allStockLinesForNotifications().filter { !$0.status.isArchived }
    }

    static func shelfBand(for line: Item, now: Date, calendar: Calendar) -> ShelfRiskBand {
        let status = line.expirationStatus(referenceNow: now, calendar: calendar)
        switch status {
        case .noShelfLife:
            return .safeOrNoShelf
        case .expired:
            return .expired
        case .expiringSoon(let expirationDate):
            let days = wholeDays(from: now, to: expirationDate, calendar: calendar)
            if days <= 7 {
                return .withinWeek
            }
            return .withinMonth
        case .ok:
            return .safeOrNoShelf
        }
    }

    private static func wholeDays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: s, to: e).day ?? 0
    }
}
