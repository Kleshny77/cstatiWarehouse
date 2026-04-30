//
//  OfflineMutationQueue.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import OSLog

private let log = Logger(subsystem: "cstatiWarehouse", category: "OfflineQueue")

enum OfflineMutation {
    case createItem(Item, organizationID: UUID)
    case updateItem(Item)
    case archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?, expectedUpdatedAt: Date)
    case deleteItem(id: UUID)
}

struct QueuedMutation: Identifiable {
    let id: UUID
    let mutation: OfflineMutation
    let createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var error: String?

    init(mutation: OfflineMutation) {
        self.id = UUID()
        self.mutation = mutation
        self.createdAt = Date()
        self.retryCount = 0
        self.lastAttemptAt = nil
        self.error = nil
    }
}

protocol OfflineMutationQueueProtocol: AnyObject {
    func enqueue(_ mutation: OfflineMutation)
    func processQueue() async
    var pendingCount: Int { get }
    func clear()
}

@Observable
final class OfflineMutationQueue: OfflineMutationQueueProtocol {

    private let warehouseService: WarehouseServiceProtocol
    private let maxRetries: Int
    private let retryDelay: TimeInterval

    private var queue: [QueuedMutation] = []
    private var isProcessing = false

    var pendingCount: Int {
        queue.count
    }

    init(
        warehouseService: WarehouseServiceProtocol,
        storage: OfflineCacheStoreProtocol,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0
    ) {
        self.warehouseService = warehouseService
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        _ = storage
    }

    func enqueue(_ mutation: OfflineMutation) {
        let queued = QueuedMutation(mutation: mutation)
        queue.append(queued)
        Task {
            await processQueue()
        }
    }

    func processQueue() async {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let mutation = queue.first {
            let success = await processMutation(mutation)

            if success {
                queue.removeFirst()
            } else {
                var updated = mutation
                updated.retryCount += 1
                updated.lastAttemptAt = Date()

                if updated.retryCount >= maxRetries {
                    queue.removeFirst()
                    log.error("Mutation \(mutation.id.uuidString, privacy: .public) failed after \(self.maxRetries) retries")
                } else {
                    queue[0] = updated
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
    }

    func clear() {
        queue.removeAll()
    }

    private func processMutation(_ queued: QueuedMutation) async -> Bool {
        await withCheckedContinuation { continuation in
            switch queued.mutation {
            case let .createItem(item, organizationID):
                warehouseService.createItem(item, organizationID: organizationID) { result in
                    continuation.resume(returning: result.isSuccess)
                }

            case let .updateItem(item):
                warehouseService.updateItem(item) { result in
                    continuation.resume(returning: result.isSuccess)
                }

            case let .archiveItem(id, quantity, reason, reasonDetail, eventID, expectedUpdatedAt):
                warehouseService.archiveItem(
                    id: id,
                    quantity: quantity,
                    reason: reason,
                    reasonDetail: reasonDetail,
                    eventID: eventID,
                    expectedUpdatedAt: expectedUpdatedAt
                ) { result in
                    continuation.resume(returning: result.isSuccess)
                }

            case let .deleteItem(id):
                warehouseService.deleteItem(id: id) { result in
                    continuation.resume(returning: result.isSuccess)
                }
            }
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
