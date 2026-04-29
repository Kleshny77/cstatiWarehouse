//
//  MyWarehouseView.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import SwiftUI

struct MyWarehouseView: View {
    @Bindable var presenter: MyWarehousePresenter
    @Namespace private var scopePickerNamespace
    @State private var selectedItem: Item? = nil
    @State private var expandedRoots: Set<UUID> = []

    init(presenter: MyWarehousePresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            VStack {
                if let notice = presenter.passiveNoticeMessage {
                    PassiveNetworkBanner(
                        message: notice,
                        onRetry: { presenter.retryWarehouseDataLoad() },
                        onDismiss: { presenter.passiveNoticeMessage = nil }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                topBar
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
                if presenter.canSwitchScope {
                    scopePicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                searchFilterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                content
            }
        }
        .sheet(item: $presenter.editPresentation) { presentation in
            if let orgID = presenter.activeOrganization?.organization.id {
                presenter.router?.makeItemEditScene(
                    mode: presentation.mode,
                    organizationID: orgID,
                    onFinish: { result in
                        presenter.editCompleted(result: result)
                    }
                )
            } else {
                EmptyView()
            }
        }
        .sheet(item: $presenter.switcherPresentation) { presentation in
            OrganizationSwitcherSheet(
                organizations: presentation.organizations,
                activeID: presenter.activeOrganization?.id,
                isLoading: presentation.isLoading,
                isCreating: presentation.isCreating,
                isJoining: presentation.isJoining,
                errorMessage: presentation.errorMessage,
                toastMessage: presenter.switcherToastMessage,
                onSelect: { summary in
                    presenter.selectOrganization(summary)
                },
                onCreate: { name in
                    presenter.createOrganization(name: name)
                },
                onJoin: { code in
                    presenter.joinOrganization(code: code)
                },
                onCancel: {
                    presenter.dismissSwitcher()
                },
                onDismissError: {
                    presenter.dismissSwitcherError()
                },
                onDismissToast: {
                    presenter.dismissSwitcherToast()
                }
            )
        }
        .sheet(item: $presenter.archivePresentation) { presentation in
            ArchiveReasonPickerView(
                itemName: presentation.item.name,
                availableQuantity: presentation.item.quantity,
                orgEvents: presentation.orgEvents,
                onConfirm: { decision in
                    presenter.confirmArchive(decision: decision)
                },
                onCancel: {
                    presenter.cancelArchive()
                }
            )
        }
        .sheet(item: $presenter.filtersPresentation) { presentation in
            WarehouseFiltersSheet(
                availableCategories: presentation.availableCategories,
                initial: presentation.current,
                onApply: { filters in
                    presenter.applyFilters(filters)
                },
                onReset: {
                    presenter.applyFilters(.none)
                },
                onCancel: {
                    presenter.filtersPresentation = nil
                }
            )
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(
                item: item,
                parentName: parentName(for: item),
                holderDisplayName: presenter.holderDisplayName(for: item),
                onEdit: presenter.canEditWarehouseItems
                    ? {
                        selectedItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            presenter.editItemRequested(item)
                        }
                    }
                    : nil,
                onArchive: (presenter.canEditWarehouseItems && !item.status.isArchived)
                    ? {
                        selectedItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            presenter.archiveItemRequested(item)
                        }
                    }
                    : nil,
                onDismiss: { selectedItem = nil }
            )
        }
        .sheet(isPresented: $presenter.isArchiveHistoryPresented) {
            ArchiveHistorySheet(
                events: presenter.archiveHistoryEvents,
                isLoading: presenter.isArchiveHistoryLoading,
                onDismiss: {
                    presenter.dismissArchiveHistory()
                }
            )
        }
        .sheet(item: $presenter.deleteConfirmation) { confirmation in
            GlassConfirmationSheet(
                title: "Удалить навсегда?",
                message: deleteConfirmationMessage(for: confirmation.item),
                confirmTitle: "Удалить",
                cancelTitle: "Отмена",
                isDestructive: true,
                onConfirm: {
                    presenter.confirmHardDelete()
                },
                onCancel: {
                    presenter.cancelHardDelete()
                }
            )
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") {
                presenter.errorMessage = nil
            }
        } message: {
            if let error = presenter.errorMessage {
                Text(error)
            }
        }
    }
    

    private var topBar: some View {
        HStack {
            profileButton
            orgSwitcherHeader
                .padding(.horizontal, 10)

            Spacer()

            if presenter.canEditWarehouseItems {
                addButton
            }
        }
    }

    private var orgSwitcherHeader: some View {
        Button {
            AppHaptics.selection()
            presenter.switcherButtonTapped()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(orgTitle)
                        .font(font: .bold, size: 24)
                        .defaultTextStyle()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(itemsCountLabel)
                    .font(font: .semiBold, size: 18)
                    .secondaryTextStyle()
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: presenter.totalItemsCount)
            }
        }
        .buttonStyle(.pressable)
        .appAnimation(AppAnimation.snap, value: presenter.activeOrganization?.id)
    }

    private var orgTitle: String {
        if let active = presenter.activeOrganization {
            return active.organization.isPersonal ? "Мой склад" : active.organization.name
        }
        return "Мой склад"
    }
    
    private var profileButton: some View {
        Button {
            presenter.profileButtonTapped()
        } label: {
            Image(systemName: "person.circle")
                .font(font: .regular, size: 34)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 60, height: 60)
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
    }
    
    private var addButton: some View {
        Button {
            AppHaptics.impact(.light)
            presenter.addButtonTapped()
        } label: {
            Image(systemName: "plus")
                .font(font: .regular, size: 34)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 60, height: 60)
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            
            TextField(
                "",
                text: $presenter.searchText,
                prompt: Text("Поиск")
                    .foregroundColor(.white.opacity(0.4))
                    .font(font: .semiBold, size: 16)
            )
            .tint(.white.opacity(0.8))
            .foregroundStyle(.white.opacity(0.8))
            .font(font: .semiBold, size: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .autocapitalization(.none)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .appGlass(in: Capsule())
    }
    
    private var filterButton: some View {
        Button {
            AppHaptics.selection()
            presenter.filterButtonTapped()
        } label: {
            Image(systemName: presenter.isFiltersActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: 50, height: 50)
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
    }
    
    private var searchFilterBar: some View {
        HStack(spacing: 10) {
            searchBar
            archiveHistoryButton
            filterButton
        }
    }

    private var archiveHistoryButton: some View {
        Button {
            presenter.archiveHistoryButtonTapped()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 50, height: 50)
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("История списаний")
    }

    private var scopePicker: some View {
        HStack(spacing: 8) {
            scopeButton(title: "Мои", scope: .mine)
            scopeButton(title: "Все", scope: .all)
        }
        .padding(4)
        .appGlass(in: Capsule())
        .appAnimation(AppAnimation.smooth, value: presenter.scope)
    }

    private func scopeButton(title: String, scope: WarehouseScope) -> some View {
        let isSelected = presenter.scope == scope
        return Button {
            AppHaptics.selection()
            withAnimation(AppAnimation.smooth) {
                presenter.selectScope(scope)
            }
        } label: {
            Text(title)
                .font(font: .semiBold, size: 16)
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .matchedGeometryEffect(id: "scopePickerSelectedBackground", in: scopePickerNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .appAnimation(AppAnimation.snap, value: presenter.scope)
    }

    @ViewBuilder
    private var content: some View {
        if presenter.shouldShowSkeleton {
            skeletonList
        } else if presenter.sections.isEmpty {
            if presenter.isAwaitingWarehouseCacheHydration {
                warehouseAwaitingCachePlaceholder
            } else {
                emptyState
            }
        } else {
            itemsList
        }
    }

    private var warehouseAwaitingCachePlaceholder: some View {
        ScrollView {
            Color.clear.frame(minHeight: 1)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await presenter.performPullToRefresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skeletonList: some View {
        List {
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    WarehouseItemCard(item: Self.skeletonItem)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .redacted(reason: .placeholder)
                }
            } header: {
                HStack {
                    Text("загрузка")
                        .font(font: .semiBold, size: 20)
                        .secondaryTextStyle()
                    Spacer()
                }
                .redacted(reason: .placeholder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .refreshable {
            await presenter.performPullToRefresh()
        }
        .allowsHitTesting(false)
        .shimmering()
    }

    private static let skeletonItem = Item(
        name: "Placeholder name",
        description: "Placeholder description text for the item card",
        categoryName: "placeholder",
        quantity: 1
    )

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 80)
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
                Text(emptyStateTitle)
                    .font(font: .semiBold, size: 20)
                    .defaultTextStyle()
                    .multilineTextAlignment(.center)
                Text(emptyStateSubtitle)
                    .font(font: .regular, size: 15)
                    .secondaryTextStyle()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await presenter.performPullToRefresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateIcon: String {
        if isFilteringOrSearching { return "magnifyingglass" }
        return presenter.scope == .mine ? "tray" : "shippingbox"
    }

    private var emptyStateTitle: String {
        if isFilteringOrSearching { return "Ничего не найдено" }
        switch presenter.scope {
        case .mine: return "На вас пока ничего не записано"
        case .all: return "На складе пусто"
        }
    }

    private var emptyStateSubtitle: String {
        if isFilteringOrSearching { return "Попробуйте изменить поиск или фильтры" }
        switch presenter.scope {
        case .mine: return "Когда кто-то выдаст вам позицию или вы добавите свою, она появится здесь"
        case .all: return "Добавьте первую позицию — и она появится здесь"
        }
    }

    private var isFilteringOrSearching: Bool {
        !presenter.searchText.trimmingCharacters(in: .whitespaces).isEmpty || presenter.isFiltersActive
    }

    private var itemsList: some View {
        List {
            ForEach(presenter.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        warehouseRootRow(for: item)

                        if item.isProductGroup, expandedRoots.contains(item.id) {
                            ForEach(activeVariants(for: item)) { variant in
                                warehouseVariantRow(for: variant)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            if presenter.canEditWarehouseItems {
                                addVariantRow(for: item)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .refreshable {
            await presenter.performPullToRefresh()
        }
        .navigationTitle("Склад")
        .appAnimation(AppAnimation.smooth, value: presenter.sections)
        .appAnimation(AppAnimation.smooth, value: expandedRoots)
    }

    private func activeVariants(for parent: Item) -> [Item] {
        parent.variants.filter { !$0.status.isArchived }
    }

    @ViewBuilder
    private func warehouseRootRow(for item: Item) -> some View {
        Group {
            if presenter.canEditWarehouseItems {
                warehouseRootRowButton(for: item)
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: !item.isProductGroup) {
                        if item.isProductGroup {
                            Button {
                                AppHaptics.selection()
                                presenter.editItemRequested(item)
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.indigo)
                            Button(role: .destructive) {
                                AppHaptics.impact(.medium)
                                presenter.hardDeleteRequested(item)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } else {
                            Button {
                                AppHaptics.impact(.medium)
                                presenter.archiveItemRequested(item)
                            } label: {
                                Label("Списать", systemImage: "archivebox")
                            }
                            .tint(.red)
                            Button {
                                AppHaptics.selection()
                                presenter.editItemRequested(item)
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                    }
            } else {
                warehouseRootRowButton(for: item)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func warehouseRootRowButton(for item: Item) -> some View {
        Button {
            AppHaptics.selection()
            if item.isProductGroup {
                toggleExpanded(item.id)
            } else {
                selectedItem = item
            }
        } label: {
            WarehouseItemCard(
                item: item,
                isExpanded: expandedRoots.contains(item.id)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func warehouseVariantRow(for variant: Item) -> some View {
        Group {
            if presenter.canEditWarehouseItems {
                warehouseVariantRowButton(for: variant)
                    .contextMenu {
                        variantContextMenu(for: variant)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            AppHaptics.impact(.medium)
                            presenter.archiveItemRequested(variant)
                        } label: {
                            Label("Списать", systemImage: "archivebox")
                        }
                        .tint(.red)
                        Button {
                            AppHaptics.selection()
                            presenter.editItemRequested(variant)
                        } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
            } else {
                warehouseVariantRowButton(for: variant)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 28, bottom: 4, trailing: 16))
    }

    private func warehouseVariantRowButton(for variant: Item) -> some View {
        Button {
            AppHaptics.selection()
            selectedItem = variant
        } label: {
            VariantInlineRow(variant: variant)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addVariantRow(for parent: Item) -> some View {
        Button {
            AppHaptics.selection()
            presenter.addVariantTapped(parent: parent)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                Text("Добавить вариант")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.pressable)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 28, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private func variantContextMenu(for variant: Item) -> some View {
        Button {
            presenter.editItemRequested(variant)
        } label: {
            Label("Редактировать", systemImage: "pencil")
        }
        Button {
            presenter.archiveItemRequested(variant)
        } label: {
            Label("Списать со склада", systemImage: "archivebox")
        }
        Divider()
        Button(role: .destructive) {
            presenter.hardDeleteRequested(variant)
        } label: {
            Label("Удалить навсегда", systemImage: "trash")
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedRoots.contains(id) {
            expandedRoots.remove(id)
        } else {
            expandedRoots.insert(id)
        }
    }

    private func deleteConfirmationMessage(for item: Item) -> String {
        if item.isProductGroup {
            let n = item.variants.count
            let variantsNote = n > 0
                ? " Удалятся все варианты (\(n))."
                : ""
            return "Группа «\(item.name)» будет удалена без возможности восстановления.\(variantsNote) Запись не попадёт в историю."
        }
        return "«\(item.name)» будет удалено без возможности восстановления и не попадёт в историю."
    }

    private func parentName(for item: Item) -> String? {
        guard let parentID = item.parentItemID else { return nil }
        for section in presenter.sections {
            if let root = section.items.first(where: { $0.id == parentID }) {
                return root.name
            }
        }
        return nil
    }
    
    @ViewBuilder
    private func sectionHeader(_ section: WarehouseSection) -> some View {
        HStack {
            Text(section.name.lowercased())
                .font(font: .semiBold, size: 20)
                .secondaryTextStyle()
            Spacer()
            Text("\(section.items.count)")
                .font(font: .regular, size: 20)
                .secondaryTextStyle()
                .contentTransition(.numericText())
                .appAnimation(AppAnimation.snap, value: section.items.count)
        }
    }
    
    @ViewBuilder
    private func itemContextMenu(for item: Item) -> some View {
        Button {
            presenter.editItemRequested(item)
        } label: {
            Label("Редактировать", systemImage: "pencil")
        }

        if item.isProductGroup {
            Button {
                presenter.addVariantTapped(parent: item)
            } label: {
                Label("Добавить вариант", systemImage: "plus.circle")
            }
        }

        if !item.isProductGroup {
            Button {
                presenter.archiveItemRequested(item)
            } label: {
                Label("Списать со склада", systemImage: "archivebox")
            }
        }

        Divider()

        Button(role: .destructive) {
            presenter.hardDeleteRequested(item)
        } label: {
            Label("Удалить навсегда", systemImage: "trash")
        }
    }


    private var itemsCountLabel: String {
        let count = presenter.totalItemsCount
        let suffix: String
        let lastTwo = count % 100
        if (11...14).contains(lastTwo) {
            suffix = "позиций"
        } else {
            switch count % 10 {
            case 1: suffix = "позиция"
            case 2, 3, 4: suffix = "позиции"
            default: suffix = "позиций"
            }
        }
        return "\(count) \(suffix)"
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.errorMessage = nil } }
        )
    }
}

#Preview {
    let coordinator = AppCoordinator()
    MyWarehouseAssembly.assemble(
        tabCoordinator: MainTabCoordinator(),
        presenter: MyWarehouseAssembly.makePresenter(appCoordinator: coordinator)
    )
}
