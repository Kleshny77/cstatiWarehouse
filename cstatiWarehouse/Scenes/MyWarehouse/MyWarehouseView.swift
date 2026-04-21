//
//  MyWarehouseView.swift
//  cstatiWarehouse
//
//  Created by Артём on 28.03.2026.
//

import SwiftUI

struct MyWarehouseView: View {
    @Bindable var presenter: MyWarehousePresenter
    @Namespace private var scopePickerNamespace
    @State private var selectedItem: Item? = nil

    init(presenter: MyWarehousePresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            VStack {
                topBar
                    .padding(.bottom, presenter.canSwitchScope ? 20 : 50)
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
                onEdit: {
                    selectedItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        presenter.editItemRequested(item)
                    }
                },
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
                message: "«\(confirmation.item.name)» будет удалено без возможности восстановления и не попадёт в историю.",
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
    
    // MARK: UI Configuration
    
    private var topBar: some View {
        HStack {
            profileButton
            orgSwitcherHeader
                .padding(.horizontal, 10)

            Spacer()

            addButton
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
            emptyState
        } else {
            itemsList
        }
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
        .allowsHitTesting(false)
    }

    private static let skeletonItem = Item(
        name: "Placeholder name",
        description: "Placeholder description text for the item card",
        categoryName: "placeholder",
        quantity: 1
    )

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
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
            Spacer()
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
                        Button {
                            AppHaptics.selection()
                            selectedItem = item
                        } label: {
                            WarehouseItemCard(item: item)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            itemContextMenu(for: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Склад")
        .appAnimation(AppAnimation.smooth, value: presenter.sections)
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

        Button {
            presenter.archiveItemRequested(item)
        } label: {
            Label("Списать со склада", systemImage: "archivebox")
        }

        Divider()

        Button(role: .destructive) {
            presenter.hardDeleteRequested(item)
        } label: {
            Label("Удалить навсегда", systemImage: "trash")
        }
    }

    // MARK: Private Methods

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
    MyWarehouseAssembly.assemble(appCoordinator: coordinator)
}
