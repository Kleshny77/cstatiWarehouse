//
//  MyWarehouseView.swift
//  cstatiWarehouse
//
//  Created by Артём on 28.03.2026.
//

import SwiftUI

struct MyWarehouseView: View {
    @Bindable var presenter: MyWarehousePresenter
    
    init(presenter: MyWarehousePresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            VStack {
                topBar
                    .padding(.bottom, 50)
                    .padding(.horizontal, 20)
                searchFilterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                itemsList
            }
        }
        .sheet(item: $presenter.editPresentation) { presentation in
            presenter.router?.makeItemEditScene(
                mode: presentation.mode,
                onFinish: { result in
                    presenter.editCompleted(result: result)
                }
            )
        }
        .sheet(item: $presenter.archivePresentation) { presentation in
            ArchiveReasonPickerView(
                itemName: presentation.item.name,
                availableQuantity: presentation.item.quantity,
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Мой склад")
                    .font(font: .bold, size: 28)
                    .defaultTextStyle()
                Text(itemsCountLabel)
                    .font(font: .semiBold, size: 20)
                    .secondaryTextStyle()
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: presenter.totalItemsCount)
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            addButton
        }
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
        HStack {
            searchBar
            filterButton
        }
    }
    
    private var itemsList: some View {
        List {
            ForEach(presenter.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        WarehouseItemCard(item: item)
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
