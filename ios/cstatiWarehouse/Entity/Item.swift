//
//  Item.swift
//  cstatiWarehouse
//
//  Created by Артём on 12.04.2026.
//

import SwiftUI

enum ItemMeasureUnit: String, Hashable, CaseIterable, Codable {
    case piece
    case liter
    case milliliter
    case kilogram
    case gram

    var menuTitle: String {
        switch self {
        case .piece: return "Штуки"
        case .liter: return "Литры"
        case .milliliter: return "Миллилитры"
        case .kilogram: return "Килограммы"
        case .gram: return "Граммы"
        }
    }

    var shortSuffix: String {
        switch self {
        case .piece: return "шт"
        case .liter: return "л"
        case .milliliter: return "мл"
        case .kilogram: return "кг"
        case .gram: return "г"
        }
    }

    static func fromAPI(_ raw: String?) -> ItemMeasureUnit {
        guard let raw else { return .piece }
        switch raw {
        case "piece": return .piece
        case "liter": return .liter
        case "milliliter": return .milliliter
        case "kilogram": return .kilogram
        case "gram": return .gram
        case "package", "meter": return .piece
        default: return .piece
        }
    }
}

struct Item: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var categoryName: String
    var quantity: Int
    var expirationDate: Date?
    var imageURL: URL?
    var createdAt: Date
    var updatedAt: Date
    var status: ItemStatus
    var heldByUserID: UUID?
    var locationAddress: String
    var parentItemID: UUID?
    var variantLabel: String
    var measureUnit: ItemMeasureUnit
    var volumePerUnit: Double?
    var variants: [Item]
    var aggregatedVolumeLiters: Double?

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        categoryName: String,
        quantity: Int = 1,
        expirationDate: Date? = nil,
        imageURL: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: ItemStatus = .inStock,
        heldByUserID: UUID? = nil,
        locationAddress: String = "",
        parentItemID: UUID? = nil,
        variantLabel: String = "",
        measureUnit: ItemMeasureUnit = .piece,
        volumePerUnit: Double? = nil,
        variants: [Item] = [],
        aggregatedVolumeLiters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.categoryName = categoryName
        self.quantity = quantity
        self.expirationDate = expirationDate
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.heldByUserID = heldByUserID
        self.locationAddress = locationAddress
        self.parentItemID = parentItemID
        self.variantLabel = variantLabel
        self.measureUnit = measureUnit
        self.volumePerUnit = volumePerUnit
        self.variants = variants
        self.aggregatedVolumeLiters = aggregatedVolumeLiters
    }

    var isProductGroup: Bool { parentItemID == nil && !variants.isEmpty }

    var isVariantLine: Bool { parentItemID != nil }

    func allStockLinesForNotifications() -> [Item] {
        if variants.isEmpty { return [self] }
        return [self] + variants
    }

    private var isLegacyFlatMilliliterTotal: Bool {
        measureUnit == .milliliter && volumePerUnit == nil
    }

    var packageCount: Int { quantity }

    var amountPerPackage: Double {
        if let v = volumePerUnit, v > 0 { return v }
        return 1
    }

    var totalAmountBase: Double {
        if isLegacyFlatMilliliterTotal {
            return Double(quantity)
        }
        return Double(quantity) * amountPerPackage
    }

    var displayTotalLiters: Double? {
        if let aggregatedVolumeLiters { return aggregatedVolumeLiters }
        let parts = variants.compactMap { v -> Double? in
            guard v.status == .inStock else { return nil }
            return v.liquidLitersEquivalent
        }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    var liquidLitersEquivalent: Double? {
        switch measureUnit {
        case .liter:
            let amt = amountPerPackage
            return Double(quantity) * amt
        case .milliliter:
            if isLegacyFlatMilliliterTotal {
                return Double(quantity) / 1000.0
            }
            return Double(quantity) * amountPerPackage / 1000.0
        case .piece, .kilogram, .gram:
            return nil
        }
    }

    var stockBadgeText: String? {
        if isProductGroup, let liters = displayTotalLiters {
            return Self.formatLitersNumber(liters) + " л"
        }
        guard quantity > 0 else { return nil }
        return stockTotalLine
    }

    var stockTotalLine: String {
        let total = totalAmountBase
        switch measureUnit {
        case .piece:
            return Self.formatIntRu(Int(total.rounded())) + " шт."
        case .liter:
            return Self.formatLitersNumber(total) + " л"
        case .milliliter:
            let ml = Int(round(total))
            return Self.displayLiquidFromTotalMilliliters(ml)
        case .kilogram:
            return Self.formatLitersNumber(total) + " кг"
        case .gram:
            return Self.formatIntRu(Int(total.rounded())) + " г"
        }
    }

    var stockPackagingLine: String {
        guard quantity > 0 else { return "Нет в наличии" }
        if isLegacyFlatMilliliterTotal {
            return Self.displayLiquidFromTotalMilliliters(quantity)
        }
        let amt = formatAmountPerPackageForDisplay()
        return "\(Self.formatIntRu(quantity)) уп. × \(amt) \(measureUnit.shortSuffix)"
    }

    var stockAccountingSummary: String {
        guard quantity > 0 else { return "Нет в наличии" }
        if isLegacyFlatMilliliterTotal {
            return Self.displayLiquidFromTotalMilliliters(quantity)
        }
        return "\(stockPackagingLine) = \(stockTotalLine)"
    }

    var stockQuantityLine: String {
        guard quantity > 0 else {
            return stockTotalLine
        }
        return stockAccountingSummary
    }

    var effectiveQuantityForSort: Int {
        if variants.isEmpty { return quantity }
        return variants.filter { !$0.status.isArchived }.map(\.quantity).reduce(0, +)
    }

    var isEffectivelyOutOfStock: Bool {
        if isProductGroup {
            return variants.filter { !$0.status.isArchived }.allSatisfy { $0.quantity == 0 }
        }
        return quantity == 0
    }

    private func formatAmountPerPackageForDisplay() -> String {
        let v = amountPerPackage
        switch measureUnit {
        case .liter, .kilogram:
            return Self.formatDecimalRu(v, maxFrac: 4)
        case .milliliter, .gram:
            if abs(v.rounded() - v) < 0.000_001 {
                return Self.formatIntRu(Int(v.rounded()))
            }
            return Self.formatDecimalRu(v, maxFrac: 2)
        case .piece:
            return Self.formatIntRu(Int(v.rounded()))
        }
    }

    private static func displayLiquidFromTotalMilliliters(_ totalMl: Int) -> String {
        guard totalMl > 0 else { return "0 мл" }
        if totalMl < 1000 {
            return Self.formatIntRu(totalMl) + " мл"
        }
        let liters = Double(totalMl) / 1000.0
        return Self.formatLitersNumber(liters) + " л"
    }

    private static func formatDecimalRu(_ value: Double, maxFrac: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFrac
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formatLitersNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static func formatIntRu(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    func expirationStatus(referenceNow: Date = .now, calendar: Calendar = .current) -> ExpirationStatus {
        guard let expirationDate else { return .noShelfLife }

        let startOfToday = calendar.startOfDay(for: referenceNow)
        let startOfExpire = calendar.startOfDay(for: expirationDate)

        if startOfExpire < startOfToday {
            return .expired
        }

        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfExpire).day ?? 0

        if days < 31 {
            return .expiringSoon(expiresAt: expirationDate)
        }

        return .ok(expiresAt: expirationDate)
    }

    func expirationStatusConsideringVariants(referenceNow: Date = .now, calendar: Calendar = .current) -> ExpirationStatus {
        let candidates: [Item] = {
            if variants.isEmpty { return [self] }
            return ([self] + variants).filter { !$0.status.isArchived }
        }()
        let statuses = candidates.map { $0.expirationStatus(referenceNow: referenceNow, calendar: calendar) }
        if statuses.contains(where: { if case .expired = $0 { return true }; return false }) {
            return .expired
        }
        let soonDates: [Date] = statuses.compactMap { s in
            if case .expiringSoon(let d) = s { return d }
            return nil
        }
        if let minSoon = soonDates.min() {
            return .expiringSoon(expiresAt: minSoon)
        }
        let okDates: [Date] = statuses.compactMap { s in
            if case .ok(let d) = s { return d }
            return nil
        }
        if let minOk = okDates.min() {
            return .ok(expiresAt: minOk)
        }
        return .noShelfLife
    }
}


enum ItemStatus: Hashable {
    case inStock
    case archived(reason: ArchiveReason, at: Date)

    var isArchived: Bool {
        if case .archived = self { return true }
        return false
    }
}


enum ArchiveReason: String, Hashable, CaseIterable, Identifiable {
    case usedAtEvent
    case expired
    case disposed
    case lost
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usedAtEvent:
            return "Использовано на мероприятии"
        case .expired:
            return "Списано по сроку"
        case .disposed:
            return "Утилизировано"
        case .lost:
            return "Утеряно"
        case .other:
            return "Другое"
        }
    }

    var requiresDetail: Bool {
        switch self {
        case .usedAtEvent, .other:
            return true
        case .expired, .disposed, .lost:
            return false
        }
    }

    var detailPlaceholder: String? {
        switch self {
        case .usedAtEvent:
            return "Название мероприятия"
        case .other:
            return "Опишите причину"
        case .expired, .disposed, .lost:
            return nil
        }
    }

    var icon: String {
        switch self {
        case .usedAtEvent:
            return "party.popper"
        case .expired:
            return "clock.badge.exclamationmark"
        case .disposed:
            return "trash"
        case .lost:
            return "questionmark.folder"
        case .other:
            return "ellipsis.circle"
        }
    }
}


enum ExpirationStatus: Equatable {
    case noShelfLife
    case expired
    case expiringSoon(expiresAt: Date)
    case ok(expiresAt: Date)

    private static let expiryFormat = Date.FormatStyle()
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.twoDigits)
        .year(.twoDigits)

    var title: String {
        switch self {
        case .noShelfLife:
            return "Без срока"
        case .expired:
            return "Просрочен"
        case .expiringSoon(let date), .ok(let date):
            return "до\u{00A0}\(date.formatted(Self.expiryFormat))"
        }
    }

    var badgeColor: Color {
        switch self {
        case .noShelfLife:
            return .gray
        case .expired:
            return .red
        case .expiringSoon:
            return .orange
        case .ok:
            return .green
        }
    }
}
