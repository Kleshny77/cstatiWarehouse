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
        .confirmationDialog(
            "Списать со склада?",
            isPresented: archiveDialogBinding,
            titleVisibility: .visible,
            presenting: presenter.archivePresentation
        ) { _ in
            ForEach(ArchiveReason.allCases) { reason in
                Button(reason.title) {
                    presenter.confirmArchive(reason: reason)
                }
            }
            Button("Отмена", role: .cancel) {
                presenter.cancelArchive()
            }
        } message: { presentation in
            Text("Позиция «\(presentation.item.name)» уйдёт в историю. Вы сможете посмотреть её позже.")
        }
        .alert(
            "Удалить навсегда?",
            isPresented: deleteAlertBinding,
            presenting: presenter.deleteConfirmation
        ) { _ in
            Button("Удалить", role: .destructive) {
                presenter.confirmHardDelete()
            }
            Button("Отмена", role: .cancel) {
                presenter.cancelHardDelete()
            }
        } message: { confirmation in
            Text("«\(confirmation.item.name)» будет удалено без возможности восстановления и не попадёт в историю.")
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
                .glassEffect()
        }
    }
    
    private var addButton: some View {
        Button {
            presenter.addButtonTapped()
        } label: {
            Image(systemName: "plus")
                .font(font: .regular, size: 34)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 60, height: 60)
                .glassEffect()
        }
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
        .glassEffect()
        .clipShape(Capsule())
    }
    
    private var filterButton: some View {
        Button {
            presenter.filterButtonTapped()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 50, height: 50)
                .glassEffect()
                .clipShape(Circle())
        }
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
                            .listRowBackground(Color.black.opacity(0.4))
                            .contextMenu {
                                itemContextMenu(for: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    presenter.archiveItemRequested(item)
                                } label: {
                                    Label("Списать", systemImage: "archivebox")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    presenter.editItemRequested(item)
                                } label: {
                                    Label("Изменить", systemImage: "pencil")
                                }
                                .tint(Color(red: 0.62, green: 0.42, blue: 0.98))
                            }
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Склад")
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
        }
    }
    
    @ViewBuilder
    private func itemContextMenu(for item: Item) -> some View {
        Button {
            presenter.editItemRequested(item)
        } label: {
            Label("Редактировать", systemImage: "pencil")
        }
        
        Menu {
            ForEach(ArchiveReason.allCases) { reason in
                Button {
                    presenter.archivePresentation = ArchivePresentation(item: item)
                    presenter.confirmArchive(reason: reason)
                } label: {
                    Label(reason.title, systemImage: reason.icon)
                }
            }
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
    
    private var archiveDialogBinding: Binding<Bool> {
        Binding(
            get: { presenter.archivePresentation != nil },
            set: { if !$0 { presenter.cancelArchive() } }
        )
    }
    
    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.deleteConfirmation != nil },
            set: { if !$0 { presenter.cancelHardDelete() } }
        )
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
