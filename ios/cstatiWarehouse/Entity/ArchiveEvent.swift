//
// ArchiveEvent.swift
// cstatiWarehouse
//

import Foundation

struct ArchiveEvent: Identifiable, Hashable {
    let id: UUID
    let itemID: UUID
    let itemName: String
    let quantity: Int
    let reason: ArchiveReason
    let reasonDetail: String
    let archivedAt: Date
    let archivedByUserID: UUID
    let archivedByDisplayName: String

    init(
        id: UUID,
        itemID: UUID,
        itemName: String,
        quantity: Int,
        reason: ArchiveReason,
        reasonDetail: String,
        archivedAt: Date,
        archivedByUserID: UUID,
        archivedByDisplayName: String
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.quantity = quantity
        self.reason = reason
        self.reasonDetail = reasonDetail
        self.archivedAt = archivedAt
        self.archivedByUserID = archivedByUserID
        self.archivedByDisplayName = archivedByDisplayName
    }
}
