//
//  Item.swift
//  cstatiWarehouse
//
//  Created by Артём on 12.04.2026.
//

import SwiftUI

/// Единица учёта остатка по строке склада (совпадает с `measure_unit` API).
enum ItemMeasureUnit: String, Hashable, CaseIterable, Codable {
    case piece
    case package
    case meter
    case liter

    var shortTitle: String {
        switch self {
        case .piece: return "шт"
        case .package: return "упак."
        case .meter: return "м"
        case .liter: return "л × упак."
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
    var status: ItemStatus
    var heldByUserID: UUID?
    var locationAddress: String?
    /// Родительская позиция (группа), если это подпозиция с другой фасовкой.
    var parentItemID: UUID?
    /// Подпись варианта, напр. «0,7 л».
    var variantLabel: String
    /// Единица учёта строки. У корня с вариантами в API часто `piece`; литры на карточке считаются по подпозициям.
    var measureUnit: ItemMeasureUnit
    /// Для `liter`: литров в одной учётной единице (упаковке).
    var volumePerUnit: Double?
    /// Подпозиции (только у корня в ответе списка).
    var variants: [Item]
    /// Сумма литров по подпозициям в стаке (только с сервера для корня).
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
        status: ItemStatus = .inStock,
        heldByUserID: UUID? = nil,
        locationAddress: String? = nil,
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

    /// Корневая карточка с несколькими фасовками.
    var isProductGroup: Bool { parentItemID == nil && !variants.isEmpty }

    /// Строка-подпозиция.
    var isVariantLine: Bool { parentItemID != nil }

    /// Все строки (корень + варианты) для сроков годности и уведомлений.
    func allStockLinesForNotifications() -> [Item] {
        if variants.isEmpty { return [self] }
        return [self] + variants
    }

    /// Сумма литров по вариантам в стаке (или `aggregatedVolumeLiters` с API).
    var displayTotalLiters: Double? {
        if let aggregatedVolumeLiters { return aggregatedVolumeLiters }
        let parts = variants.compactMap { v -> Double? in
            guard v.measureUnit == .liter, let vol = v.volumePerUnit, v.status == .inStock else { return nil }
            return Double(v.quantity) * vol
        }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    /// Текст для бейджа количества на карточке.
    var quantityBadgePrimary: String? {
        if isProductGroup, let liters = displayTotalLiters {
            return formatLiters(liters)
        }
        if quantity > 0 {
            return "\(quantity)"
        }
        return nil
    }

    /// Подпись единицы рядом с числом (для не-групп).
    var quantityBadgeUnitSuffix: String? {
        if isProductGroup { return nil }
        guard quantity > 0 else { return nil }
        return measureUnit.shortTitle
    }

    /// Суммарное количество для сортировки «по количеству» (группа — сумма по вариантам).
    var effectiveQuantityForSort: Int {
        if variants.isEmpty { return quantity }
        return variants.filter { !$0.status.isArchived }.map(\.quantity).reduce(0, +)
    }

    /// Пустой остаток с учётом вариантов.
    var isEffectivelyOutOfStock: Bool {
        if isProductGroup {
            return variants.filter { !$0.status.isArchived }.allSatisfy { $0.quantity == 0 }
        }
        return quantity == 0
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

    /// Для карточки-группы учитывает сроки всех подпозиций (самая «ранняя» проблема).
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

    private func formatLiters(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let num = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(num) л"
    }
}

// MARK: - ItemStatus

enum ItemStatus: Hashable {
    case inStock
    case archived(reason: ArchiveReason, at: Date)

    var isArchived: Bool {
        if case .archived = self { return true }
        return false
    }
}

// MARK: - ArchiveReason

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

    /// Требует ли причина текстового пояснения (название мероприятия, детали «другое»).
    var requiresDetail: Bool {
        switch self {
        case .usedAtEvent, .other:
            return true
        case .expired, .disposed, .lost:
            return false
        }
    }

    /// Подсказка для поля ввода подробностей.
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

// MARK: - ExpirationStatus

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
            return "до \(date.formatted(Self.expiryFormat))"
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
