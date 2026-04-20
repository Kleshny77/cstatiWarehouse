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
    func switcherButtonTapped()

    func editItemRequested(_ item: Item)
    func archiveItemRequested(_ item: Item)
    func hardDeleteRequested(_ item: Item)

    func confirmArchive(decision: ArchiveDecision)
    func cancelArchive()
    func confirmHardDelete()
    func cancelHardDelete()

    func selectOrganization(_ summary: OrganizationSummary)
    func createOrganization(name: String)
    func joinOrganization(code: String)
    func dismissSwitcher()
    func dismissSwitcherError()

    func applyFilters(_ filters: WarehouseFilters)
    func editCompleted(result: ItemEditResult)
    func selectScope(_ scope: WarehouseScope)

    func archiveHistoryButtonTapped()
    func dismissArchiveHistory()
}

@Observable
final class MyWarehousePresenter: MyWarehousePresenterProtocol {
    // MARK: Properties

    var interactor: MyWarehouseInteractorInputProtocol?
    var router: MyWarehouseRouterProtocol?

    var sections: [WarehouseSection] = []
    var totalItemsCount: Int = 0
    var searchText: String = "" {
        didSet {
            searchTextByScope[scope] = searchText
            rebuildSections()
        }
    }
    var isLoading: Bool = false
    var errorMessage: String?

    var activeOrganization: OrganizationSummary?
    var switcherPresentation: SwitcherPresentation?

    var editPresentation: ItemEditPresentation?
    var archivePresentation: ArchivePresentation?
    var deleteConfirmation: DeleteConfirmation?
    var filtersPresentation: FiltersPresentation?

    /// История списаний (архивные операции с деталями).
    var isArchiveHistoryPresented = false
    var archiveHistoryEvents: [ArchiveEvent] = []
    var isArchiveHistoryLoading = false

    var filters: WarehouseFilters = .none {
        didSet { filtersByScope[scope] = filters }
    }
    var isFiltersActive: Bool { filters.isActive }

    /// Текущий скоуп списка. Для обычных участников всегда `.mine` (бэкенд всё равно сузит).
    /// Для admin/owner — переключается сегментом "Мои / Все".
    var scope: WarehouseScope = .mine
    /// Показывать ли сегмент-переключатель "Мои / Все".
    /// Прячем в персональной организации и у обычных участников.
    var canSwitchScope: Bool {
        guard let summary = activeOrganization else { return false }
        if summary.organization.isPersonal { return false }
        return summary.role.canManageMembers
    }

    private var allItems: [Item] = []
    private var hasResolvedOrganization: Bool = false
    private var searchTextByScope: [WarehouseScope: String] = [:]
    private var filtersByScope: [WarehouseScope: WarehouseFilters] = [:]
    private var loadedScopes: Set<WarehouseScope> = []

    /// Показываем скелетон только при первой загрузке текущего скоупа.
    /// Если скоуп уже однажды загружался (даже пустым), дальше показываем обычный empty-state.
    var shouldShowSkeleton: Bool {
        isLoading && sections.isEmpty && !loadedScopes.contains(scope)
    }

    // MARK: Public Methods

    func viewDidLoad() {
        guard !hasResolvedOrganization else { return }
        hasResolvedOrganization = true
        isLoading = true
        interactor?.resolveActiveOrganization()
    }

    func addButtonTapped() {
        guard activeOrganization != nil else { return }
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

    func switcherButtonTapped() {
        switcherPresentation = SwitcherPresentation(
            organizations: [],
            isLoading: true,
            isCreating: false,
            isJoining: false,
            errorMessage: nil
        )
        interactor?.loadMyOrganizations()
    }

    func editItemRequested(_ item: Item) {
        editPresentation = ItemEditPresentation(mode: .edit(item))
    }

    func archiveItemRequested(_ item: Item) {
        interactor?.prepareArchive(for: item)
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
            reasonDetail: decision.detail,
            eventID: decision.eventID
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

    func selectOrganization(_ summary: OrganizationSummary) {
        switcherPresentation = nil
        if summary.id == activeOrganization?.id { return }
        interactor?.selectActiveOrganization(summary.organization.id)
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
    }

    func createOrganization(name: String) {
        guard var pres = switcherPresentation else { return }
        pres.isCreating = true
        pres.errorMessage = nil
        switcherPresentation = pres
        interactor?.createOrganization(name: name)
    }

    func joinOrganization(code: String) {
        guard var pres = switcherPresentation else { return }
        pres.isJoining = true
        pres.errorMessage = nil
        switcherPresentation = pres
        interactor?.joinOrganization(code: code)
    }

    func dismissSwitcher() {
        switcherPresentation = nil
    }

    func dismissSwitcherError() {
        switcherPresentation?.errorMessage = nil
    }

    func applyFilters(_ filters: WarehouseFilters) {
        self.filters = filters
        filtersPresentation = nil
        rebuildSections()
    }

    func archiveHistoryButtonTapped() {
        guard let orgID = activeOrganization?.organization.id else { return }
        AppHaptics.selection()
        isArchiveHistoryPresented = true
        isArchiveHistoryLoading = true
        archiveHistoryEvents = []
        interactor?.loadArchiveEvents(organizationID: orgID)
    }

    func dismissArchiveHistory() {
        isArchiveHistoryPresented = false
        isArchiveHistoryLoading = false
    }

    func selectScope(_ newScope: WarehouseScope) {
        guard canSwitchScope, newScope != scope else { return }
        // Запомнить search/filters текущего скоупа уже случилось в их didSet.
        scope = newScope
        // Восстановить сохранённое состояние search/filters для нового скоупа.
        let restoredSearch = searchTextByScope[scope] ?? ""
        if searchText != restoredSearch {
            searchText = restoredSearch
        }
        let restoredFilters = filtersByScope[scope] ?? .none
        if filters != restoredFilters {
            filters = restoredFilters
        }
        guard let orgID = activeOrganization?.organization.id else { return }
        allItems = []
        rebuildSections()
        isLoading = true
        interactor?.loadActiveItems(organizationID: orgID, scope: scope)
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

    /// Сбрасывает запомнённые search/filters при смене организации, чтобы не тянуть
    /// контекст одной орги в другую. scope всегда стартует с `.mine`.
    private func resetScopeStateForNewOrganization() {
        searchTextByScope = [:]
        filtersByScope = [:]
        loadedScopes = []
        scope = .mine
        if !searchText.isEmpty { searchText = "" }
        if filters != .none { filters = .none }
    }

    private var availableCategories: [String] {
        let active = allItems.filter { !$0.status.isArchived }
        let names = Set(active.map(\.categoryName))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return names.sorted { $0.localizedCompare($1) == .orderedAscending }
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
    func activeOrganizationResolved(_ summary: OrganizationSummary?) {
        activeOrganization = summary
        if let summary {
            resetScopeStateForNewOrganization()
            interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
        } else {
            isLoading = false
            allItems = []
            rebuildSections()
        }
    }

    func organizationsLoaded(_ organizations: [OrganizationSummary]) {
        guard var pres = switcherPresentation else { return }
        pres.organizations = organizations
        pres.isLoading = false
        switcherPresentation = pres
    }

    func organizationCreated(_ summary: OrganizationSummary) {
        switcherPresentation = nil
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
    }

    func archiveReady(item: Item, orgEvents: [OrgEvent]) {
        archivePresentation = ArchivePresentation(item: item, orgEvents: orgEvents)
    }

    func itemsLoaded(_ items: [Item]) {
        loadedScopes.insert(scope)
        allItems = items
        isLoading = false
        rebuildSections()
    }

    func archiveEventsLoaded(_ events: [ArchiveEvent]) {
        archiveHistoryEvents = events
        isArchiveHistoryLoading = false
    }

    func archiveHistoryFailed(_ message: String) {
        isArchiveHistoryLoading = false
        errorMessage = message
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
        loadedScopes.insert(scope)
        isLoading = false
        errorMessage = error
    }

    func organizationFailed(error: String) {
        if switcherPresentation != nil {
            switcherPresentation?.isLoading = false
            switcherPresentation?.isCreating = false
            switcherPresentation?.isJoining = false
            switcherPresentation?.errorMessage = error
        } else {
            errorMessage = error
        }
    }

    func organizationJoined(_ summary: OrganizationSummary) {
        switcherPresentation = nil
        if summary.id == activeOrganization?.id {
            isLoading = true
            interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
            return
        }
        interactor?.selectActiveOrganization(summary.organization.id)
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
    }
}
