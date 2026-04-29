//
//  OfflineMutationQueue.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

/// Типы офлайн-мутаций, которые можно поставить в очередь.
enum OfflineMutation: Codable {
    case createItem(Item, organizationID: UUID)
    case updateItem(Item)
    case archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?, expectedUpdatedAt: Date)
    case deleteItem(id: UUID)
}

/// Запись в очереди офлайн-мутаций.
struct QueuedMutation: Codable, Identifiable {
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

/// Протокол очереди офлайн-мутаций.
protocol OfflineMutationQueueProtocol: AnyObject {
    /// Добавить мутацию в очередь.
    func enqueue(_ mutation: OfflineMutation)
    
    /// Запустить обработку очереди.
    func processQueue() async
    
    /// Количество ожидающих мутаций.
    var pendingCount: Int { get }
    
    /// Очистить все мутации (для тестов).
    func clear()
}

/// Очередь офлайн-мутаций с автоматическими повторами.
/// Использует OperationQueue для последовательного выполнения мутаций.
@Observable
final class OfflineMutationQueue: OfflineMutationQueueProtocol {
    
    private let warehouseService: WarehouseServiceProtocol
    private let storage: OfflineCacheStoreProtocol
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
        self.storage = storage
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        loadQueue()
    }
    
    func enqueue(_ mutation: OfflineMutation) {
        let queued = QueuedMutation(mutation: mutation)
        queue.append(queued)
        saveQueue()
        
        // Автоматически запускаем обработку
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
                // Успешно выполнено - удаляем из очереди
                queue.removeFirst()
                saveQueue()
            } else {
                // Ошибка - обновляем счётчик повторов
                var updated = mutation
                updated.retryCount += 1
                updated.lastAttemptAt = Date()
                
                if updated.retryCount >= maxRetries {
                    // Превышен лимит повторов - удаляем
                    queue.removeFirst()
                    saveQueue()
                    print("⚠️ Mutation \(mutation.id) failed after \(maxRetries) retries")
                } else {
                    // Обновляем запись и ждём перед следующей попыткой
                    queue[0] = updated
                    saveQueue()
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
    }
    
    func clear() {
        queue.removeAll()
        saveQueue()
    }
    
    // MARK: - Private
    
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
    
    private func loadQueue() {
        guard let data = storage.get(key: OfflineCacheKeys.offlineMutationQueue),
              let decoded = try? JSONDecoder().decode([QueuedMutation].self, from: data) else {
            return
        }
        queue = decoded
    }
    
    private func saveQueue() {
        guard let encoded = try? JSONEncoder().encode(queue) else { return }
        storage.set(key: OfflineCacheKeys.offlineMutationQueue, value: encoded)
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
