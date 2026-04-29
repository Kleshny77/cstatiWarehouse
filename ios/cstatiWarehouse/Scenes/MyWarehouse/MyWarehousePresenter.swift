//
//  MyWarehousePresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
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
    func addVariantTapped(parent: Item)
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

    func retryWarehouseDataLoad()

    func performPullToRefresh() async
    func handleWarehouseTabAppeared()
}

@Observable
final class MyWarehousePresenter: MyWarehousePresenterProtocol {

    weak var tabCoordinator: MainTabCoordinator?

    var interactor: MyWarehouseInteractorInputProtocol?
    var router: MyWarehouseRouterProtocol?
    var shelfLifeNotifier: ShelfLifeNotificationServiceProtocol = AppServices.shelfLifeNotifier

    var sections: [WarehouseSection] = []
    var organizationMembers: [OrganizationMember] = []
    var totalItemsCount: Int = 0
    var searchText: String = "" {
        didSet {
            searchTextByScope[scope] = searchText
            rebuildSections()
        }
    }
    var isLoading: Bool = false
    /// После смены сегмента «Мои»/«Все»: не показываем скелетон, пока не выяснили, есть ли снимок в кэше.
    private(set) var isAwaitingWarehouseCacheHydration: Bool = false
    var errorMessage: String?
    var passiveNoticeMessage: String?

    var activeOrganization: OrganizationSummary?
    var switcherPresentation: SwitcherPresentation?
    var switcherToastMessage: String?

    var editPresentation: ItemEditPresentation?
    var archivePresentation: ArchivePresentation?
    var deleteConfirmation: DeleteConfirmation?
    var filtersPresentation: FiltersPresentation?

    var isArchiveHistoryPresented = false
    var archiveHistoryEvents: [ArchiveEvent] = []
    var isArchiveHistoryLoading = false

    var filters: WarehouseFilters = .none {
        didSet { filtersByScope[scope] = filters }
    }
    var isFiltersActive: Bool { filters.isActive }

    var scope: WarehouseScope = .mine
    var canSwitchScope: Bool {
        guard let summary = activeOrganization else { return false }
        if summary.organization.isPersonal { return false }
        return summary.role.canManageMembers
    }

    private var allItems: [Item] = []
    private var switcherToastDismissTask: Task<Void, Never>?
    private var hasResolvedOrganization: Bool = false
    private var searchTextByScope: [WarehouseScope: String] = [:]
    private var filtersByScope: [WarehouseScope: WarehouseFilters] = [:]
    private var loadedScopes: Set<WarehouseScope> = []
    private var pullToRefreshContinuation: CheckedContinuation<Void, Never>?

    var shouldShowSkeleton: Bool {
        !isAwaitingWarehouseCacheHydration
            && isLoading
            && sections.isEmpty
            && !loadedScopes.contains(scope)
    }


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

    func addVariantTapped(parent: Item) {
        editPresentation = ItemEditPresentation(mode: .createVariant(parent: parent))
    }

    func archiveItemRequested(_ item: Item) {
        if item.isProductGroup {
            errorMessage = "Чтобы списать, откройте карточку и выберите конкретный вариант."
            return
        }
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
        dismissSwitcherToast()
        switcherPresentation = nil
        if summary.id == activeOrganization?.id { return }
        interactor?.selectActiveOrganization(summary.organization.id)
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        requestMembersForActiveOrganization()
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
        switcherToastDismissTask?.cancel()
        switcherToastDismissTask = nil
        switcherToastMessage = nil
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

    func holderDisplayName(for item: Item) -> String? {
        guard let uid = item.heldByUserID else { return nil }
        guard let member = organizationMembers.first(where: { $0.userID == uid }) else { return nil }
        if let full = member.fullName, !full.isEmpty { return full }
        if let email = member.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return nil
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

    func retryWarehouseDataLoad() {
        passiveNoticeMessage = nil
        errorMessage = nil
        isLoading = true
        if let orgID = activeOrganization?.organization.id {
            requestMembersForActiveOrganization()
            interactor?.loadActiveItems(organizationID: orgID, scope: scope)
        } else {
            interactor?.resolveActiveOrganization()
        }
    }

    func performPullToRefresh() async {
        await withCheckedContinuation { continuation in
            guard activeOrganization?.organization.id != nil else {
                continuation.resume()
                return
            }
            pullToRefreshContinuation = continuation
            passiveNoticeMessage = nil
            errorMessage = nil
            requestMembersForActiveOrganization()
            if let orgID = activeOrganization?.organization.id {
                interactor?.loadActiveItems(organizationID: orgID, scope: scope)
            }
        }
    }

    func handleWarehouseTabAppeared() {
        guard let key = tabCoordinator?.takePendingWarehouseCategoryFilterKey() else { return }
        var next = filters
        next.selectedCategories = [key]
        applyFilters(next)
    }

    private func finishPullToRefreshIfNeeded() {
        guard let continuation = pullToRefreshContinuation else { return }
        pullToRefreshContinuation = nil
        continuation.resume()
    }

    func selectScope(_ newScope: WarehouseScope) {
        guard canSwitchScope, newScope != scope else { return }
        loadedScopes.remove(newScope)
        scope = newScope
        let restoredSearch = searchTextByScope[scope] ?? ""
        if searchText != restoredSearch {
            searchText = restoredSearch
        }
        let restoredFilters = filtersByScope[scope] ?? .none
        if filters != restoredFilters {
            filters = restoredFilters
        }
        guard let orgID = activeOrganization?.organization.id else { return }
        isAwaitingWarehouseCacheHydration = true
        isLoading = false
        allItems = []
        rebuildSections()
        interactor?.loadActiveItems(organizationID: orgID, scope: scope)
    }

    func editCompleted(result: ItemEditResult) {
        let wasCreate: Bool = {
            guard let mode = editPresentation?.mode else { return false }
            switch mode {
            case .create, .createVariant:
                return true
            case .edit:
                return false
            }
        }()
        editPresentation = nil

        switch result {
        case .saved(let item):
            interactor?.applyExternalChange(item, isNew: wasCreate)
        case .cancelled:
            break
        }
    }


    private func requestMembersForActiveOrganization() {
        guard let orgID = activeOrganization?.organization.id else {
            organizationMembers = []
            return
        }
        interactor?.loadOrganizationMembers(organizationID: orgID)
    }

    private func resetScopeStateForNewOrganization() {
        searchTextByScope = [:]
        filtersByScope = [:]
        loadedScopes = []
        isAwaitingWarehouseCacheHydration = false
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
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            searched = active
        } else {
            searched = active.filter { root in
                root.name.localizedCaseInsensitiveContains(query)
                    || (root.description?.localizedCaseInsensitiveContains(query) ?? false)
                    || root.variants.contains { v in
                        v.variantLabel.localizedCaseInsensitiveContains(query)
                    }
            }
        }

        let filtered = applyCurrentFilters(to: searched)

        if !(isAwaitingWarehouseCacheHydration && allItems.isEmpty) {
            totalItemsCount = filtered.count
        }

        let sorted = sortItems(filtered, by: filters.sort)
        let grouped = Dictionary(grouping: sorted, by: { $0.categoryName })
        sections = grouped.keys.sorted().map { name in
            WarehouseSection(
                name: name,
                items: grouped[name] ?? []
            )
        }
    }

    private func normalizedCategoryKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func categoryMatchesFilter(selected: Set<String>, itemCategory: String) -> Bool {
        let itemKey = normalizedCategoryKey(itemCategory)
        return selected.contains { normalizedCategoryKey($0) == itemKey }
    }

    private func applyCurrentFilters(to items: [Item]) -> [Item] {
        var result = items
        if !filters.selectedCategories.isEmpty {
            result = result.filter { item in
                categoryMatchesFilter(selected: filters.selectedCategories, itemCategory: item.categoryName)
            }
        }
        if !filters.expirationSet.isEmpty {
            result = result.filter { item in
                let status = item.expirationStatusConsideringVariants()
                return filters.expirationSet.contains { $0.matches(status) }
            }
        }
        if !filters.smartFilters.isEmpty {
            result = result.filter { item in
                filters.smartFilters.allSatisfy { $0.matches(item) }
            }
        }
        return result
    }

    private func syncShelfLifeNotifications() {
        guard let summary = activeOrganization else { return }
        let lines = allItems.flatMap { $0.allStockLinesForNotifications() }
        shelfLifeNotifier.synchronize(
            organizationID: summary.organization.id,
            organizationName: summary.organization.name,
            items: lines
        )
    }

    private func sortItems(_ items: [Item], by option: WarehouseSortOption) -> [Item] {
        switch option {
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .quantityAsc:
            return items.sorted { $0.effectiveQuantityForSort < $1.effectiveQuantityForSort }
        case .quantityDesc:
            return items.sorted { $0.effectiveQuantityForSort > $1.effectiveQuantityForSort }
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


extension MyWarehousePresenter: MyWarehouseInteractorOutputProtocol {
    func activeOrganizationResolved(_ summary: OrganizationSummary?) {
        passiveNoticeMessage = nil
        let previousOrganizationID = activeOrganization?.organization.id
        activeOrganization = summary
        if let summary {
            if let previousOrganizationID, previousOrganizationID != summary.organization.id {
                resetScopeStateForNewOrganization()
            }
            requestMembersForActiveOrganization()
            interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
        } else {
            organizationMembers = []
            isLoading = false
            isAwaitingWarehouseCacheHydration = false
            allItems = []
            rebuildSections()
            finishPullToRefreshIfNeeded()
        }
    }

    func organizationsLoaded(_ organizations: [OrganizationSummary]) {
        guard var pres = switcherPresentation else { return }
        pres.organizations = organizations
        pres.isLoading = false
        switcherPresentation = pres
    }

    func organizationCreated(_ summary: OrganizationSummary) {
        dismissSwitcherToast()
        switcherPresentation = nil
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        requestMembersForActiveOrganization()
        interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
    }

    func archiveReady(item: Item, orgEvents: [OrgEvent]) {
        archivePresentation = ArchivePresentation(item: item, orgEvents: orgEvents)
    }

    func itemsLoaded(_ items: [Item]) {
        passiveNoticeMessage = nil
        isAwaitingWarehouseCacheHydration = false
        loadedScopes.insert(scope)
        allItems = items
        isLoading = false
        rebuildSections()
        syncShelfLifeNotifications()
        finishPullToRefreshIfNeeded()
    }

    func warehouseActiveItemsCacheMissed() {
        isAwaitingWarehouseCacheHydration = false
        isLoading = true
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
        if let parentID = item.parentItemID,
           let pIdx = allItems.firstIndex(where: { $0.id == parentID }) {
            var parent = allItems[pIdx]
            if let vIdx = parent.variants.firstIndex(where: { $0.id == item.id }) {
                parent.variants[vIdx] = item
            } else {
                parent.variants.append(item)
            }
            allItems[pIdx] = parent
        } else if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[idx] = item
        }
        rebuildSections()
        syncShelfLifeNotifications()
    }

    func itemDeleted(id: UUID) {
        if let pIdx = allItems.firstIndex(where: { $0.variants.contains(where: { $0.id == id }) }) {
            var parent = allItems[pIdx]
            parent.variants.removeAll { $0.id == id }
            allItems[pIdx] = parent
        } else {
            allItems.removeAll { $0.id == id }
        }
        rebuildSections()
        syncShelfLifeNotifications()
    }

    func itemChangedExternally(_ item: Item, isNew: Bool) {
        if let parentID = item.parentItemID,
           let pIdx = allItems.firstIndex(where: { $0.id == parentID }) {
            var parent = allItems[pIdx]
            if let vIdx = parent.variants.firstIndex(where: { $0.id == item.id }) {
                parent.variants[vIdx] = item
            } else {
                parent.variants.append(item)
                parent.variants.sort { $0.createdAt > $1.createdAt }
            }
            allItems[pIdx] = parent
        } else if isNew {
            allItems.append(item)
        } else if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            var merged = item
            if merged.variants.isEmpty, !allItems[idx].variants.isEmpty {
                merged.variants = allItems[idx].variants
            }
            allItems[idx] = merged
        } else {
            allItems.append(item)
        }
        rebuildSections()
        syncShelfLifeNotifications()
    }

    func initialLoadFailed(message: String) {
        isLoading = false
        isAwaitingWarehouseCacheHydration = false
        activeOrganization = nil
        organizationMembers = []
        allItems = []
        rebuildSections()
        passiveNoticeMessage = message
        finishPullToRefreshIfNeeded()
    }

    func membersLoaded(_ members: [OrganizationMember]) {
        organizationMembers = members
    }

    func itemsLoadFailed(message: String) {
        loadedScopes.insert(scope)
        isAwaitingWarehouseCacheHydration = false
        isLoading = false
        if allItems.isEmpty {
            passiveNoticeMessage = message
        } else {
            passiveNoticeMessage = "Не удалось обновить список. Показаны сохранённые данные."
        }
        finishPullToRefreshIfNeeded()
    }

    func failed(error: String) {
        loadedScopes.insert(scope)
        isAwaitingWarehouseCacheHydration = false
        isLoading = false
        errorMessage = error
        finishPullToRefreshIfNeeded()
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

    func joinAlreadyInOrganization() {
        if var pres = switcherPresentation {
            pres.isJoining = false
            pres.errorMessage = nil
            switcherPresentation = pres
        }
        switcherToastDismissTask?.cancel()
        switcherToastMessage = OrganizationsError.alreadyMember.message
        AppHaptics.warning()
        switcherToastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            switcherToastMessage = nil
        }
    }

    func dismissSwitcherToast() {
        switcherToastDismissTask?.cancel()
        switcherToastDismissTask = nil
        switcherToastMessage = nil
    }

    func organizationJoined(_ summary: OrganizationSummary) {
        dismissSwitcherToast()
        switcherPresentation = nil
        if summary.id == activeOrganization?.id {
            isLoading = true
            requestMembersForActiveOrganization()
            interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
            return
        }
        interactor?.selectActiveOrganization(summary.organization.id)
        activeOrganization = summary
        resetScopeStateForNewOrganization()
        allItems = []
        rebuildSections()
        isLoading = true
        requestMembersForActiveOrganization()
        interactor?.loadActiveItems(organizationID: summary.organization.id, scope: scope)
    }
}
