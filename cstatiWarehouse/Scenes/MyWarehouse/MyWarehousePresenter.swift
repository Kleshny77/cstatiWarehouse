//
//  MyWarehousePresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import SwiftUI

protocol MyWarehousePresenterProtocol: AnyObject {
    func viewDidLoad()
    func addButtonTapped()
    func profileButtonTapped()
    func filterButtonTapped()
    
    func editItemRequested(_ item: Item)
    func archiveItemRequested(_ item: Item)
    func hardDeleteRequested(_ item: Item)
    
    func confirmArchive(reason: ArchiveReason)
    func cancelArchive()
    func confirmHardDelete()
    func cancelHardDelete()
    
    func editCompleted(result: ItemEditResult)
}

@Observable
final class MyWarehousePresenter: MyWarehousePresenterProtocol {
    // MARK: Properties
    
    var interactor: MyWarehouseInteractorInputProtocol?
    var router: MyWarehouseRouterProtocol?
    
    var sections: [WarehouseSection] = []
    var totalItemsCount: Int = 0
    var searchText: String = "" {
        didSet { rebuildSections() }
    }
    var isLoading: Bool = false
    var errorMessage: String?
    
    var editPresentation: ItemEditPresentation?
    var archivePresentation: ArchivePresentation?
    var deleteConfirmation: DeleteConfirmation?
    
    private var allItems: [Item] = []
    
    // MARK: Public Methods
    
    func viewDidLoad() {
        loadItems()
    }
    
    func addButtonTapped() {
        editPresentation = ItemEditPresentation(mode: .create(suggestedCategory: nil))
    }
    
    func profileButtonTapped() {
        router?.navigateToProfile()
    }
    
    func filterButtonTapped() {
        // TODO: открыть фильтры (категория, срок, статус)
    }
    
    func editItemRequested(_ item: Item) {
        editPresentation = ItemEditPresentation(mode: .edit(item))
    }
    
    func archiveItemRequested(_ item: Item) {
        archivePresentation = ArchivePresentation(item: item)
    }
    
    func hardDeleteRequested(_ item: Item) {
        deleteConfirmation = DeleteConfirmation(item: item)
    }
    
    func confirmArchive(reason: ArchiveReason) {
        guard let item = archivePresentation?.item else { return }
        archivePresentation = nil
        interactor?.archiveItem(id: item.id, reason: reason, at: .now)
    }
    
    func cancelArchive() {
        archivePresentation = nil
    }
    
    func confirmHardDelete() {
        guard let item = deleteConfirmation?.item else { return }
        deleteConfirmation = nil
        interactor?.deleteItem(id: item.id)
    }
    
    func cancelHardDelete() {
        deleteConfirmation = nil
    }
    
    func editCompleted(result: ItemEditResult) {
        let wasCreate: Bool = {
            guard let mode = editPresentation?.mode else { return false }
            if case .create = mode { return true }
            return false
        }()
        editPresentation = nil
        
        switch result {
        case .saved(let item):
            interactor?.applyExternalChange(item, isNew: wasCreate)
        case .cancelled:
            break
        }
    }
    
    // MARK: Private Methods
    
    private func loadItems() {
        isLoading = true
        interactor?.loadActiveItems()
    }
    
    private func rebuildSections() {
        let active = allItems.filter { !$0.status.isArchived }
        let filtered: [Item]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = active
        } else {
            filtered = active.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        totalItemsCount = filtered.count
        
        let grouped = Dictionary(grouping: filtered, by: { $0.categoryName })
        sections = grouped.keys.sorted().map { name in
            WarehouseSection(
                name: name,
                items: grouped[name]!.sorted { $0.createdAt > $1.createdAt }
            )
        }
    }
}

// MARK: - MyWarehouseInteractorOutputProtocol

extension MyWarehousePresenter: MyWarehouseInteractorOutputProtocol {
    func itemsLoaded(_ items: [Item]) {
        allItems = items
        isLoading = false
        rebuildSections()
    }
    
    func itemArchived(_ item: Item) {
        if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[idx] = item
        }
        rebuildSections()
    }
    
    func itemDeleted(id: UUID) {
        allItems.removeAll { $0.id == id }
        rebuildSections()
    }
    
    func itemChangedExternally(_ item: Item, isNew: Bool) {
        if isNew {
            allItems.append(item)
        } else if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[idx] = item
        } else {
            allItems.append(item)
        }
        rebuildSections()
    }
    
    func failed(error: String) {
        isLoading = false
        errorMessage = error
    }
}
