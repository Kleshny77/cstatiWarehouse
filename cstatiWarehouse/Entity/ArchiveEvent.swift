//
// ArchiveEvent.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

/// Запись о списании quantity единиц с позиции склада.
/// Одна позиция может породить много событий (разные мероприятия, части партии).
struct ArchiveEvent: Identifiable, Hashable {
    let id: UUID
    let itemID: UUID
    let quantity: Int
    let reason: ArchiveReason
    let reasonDetail: String
    let archivedAt: Date
}
