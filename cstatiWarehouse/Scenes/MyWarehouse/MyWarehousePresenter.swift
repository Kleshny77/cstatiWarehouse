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

    func confirmArchive(decision: ArchiveDecision)
    func cancelArchive()
    func confirmHardDelete()
    func cancelHardDelete()

    func applyFilters(_ filters: WarehouseFilters)
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
    var filtersPresentation: FiltersPresentation?

    var filters: WarehouseFilters = .none
    var isFiltersActive: Bool { filters.isActive }

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
        filtersPresentation = FiltersPresentation(
            availableCategories: availableCategories,
            current: filters
        )
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

    func confirmArchive(decision: ArchiveDecision) {
        guard let item = archivePresentation?.item else { return }
        archivePresentation = nil
        interactor?.archiveItem(
            id: item.id,
            quantity: decision.quantity,
            reason: decision.reason,
            reasonDetail: decision.detail
        )
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

    func applyFilters(_ filters: WarehouseFilters) {
        self.filters = filters
        filtersPresentation = nil
        rebuildSections()
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

    private var availableCategories: [String] {
        let active = allItems.filter { !$0.status.isArchived }
        let names = Set(active.map(\.categoryName))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return names.sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    private func loadItems() {
        isLoading = true
        interactor?.loadActiveItems()
    }

    private func rebuildSections() {
        let active = allItems.filter { !$0.status.isArchived }

        let searched: [Item]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            searched = active
        } else {
            searched = active.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        let filtered = applyCurrentFilters(to: searched)

        totalItemsCount = filtered.count

        let sorted = sortItems(filtered, by: filters.sort)
        let grouped = Dictionary(grouping: sorted, by: { $0.categoryName })
        sections = grouped.keys.sorted().map { name in
            WarehouseSection(
                name: name,
                items: grouped[name] ?? []
            )
        }
    }

    private func applyCurrentFilters(to items: [Item]) -> [Item] {
        var result = items
        if !filters.selectedCategories.isEmpty {
            result = result.filter { filters.selectedCategories.contains($0.categoryName) }
        }
        if !filters.expirationSet.isEmpty {
            result = result.filter { item in
                let status = item.expirationStatus()
                return filters.expirationSet.contains { $0.matches(status) }
            }
        }
        return result
    }

    private func sortItems(_ items: [Item], by option: WarehouseSortOption) -> [Item] {
        switch option {
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .quantityAsc:
            return items.sorted { $0.quantity < $1.quantity }
        case .quantityDesc:
            return items.sorted { $0.quantity > $1.quantity }
        case .expirationAsc:
            return items.sorted { lhs, rhs in
                switch (lhs.expirationDate, rhs.expirationDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.createdAt > rhs.createdAt
                }
            }
        case .nameAsc:
            return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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
