//
//  Item.swift
//  cstatiWarehouse
//
//  Created by Артём on 12.04.2026.
//

import SwiftUI

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
        locationAddress: String? = nil
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
