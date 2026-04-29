//
//  WarehouseFiltersSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct WarehouseFiltersSheet: View {


    let availableCategories: [String]
    let initial: WarehouseFilters
    let onApply: (WarehouseFilters) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    @State private var draft: WarehouseFilters


    init(
        availableCategories: [String],
        initial: WarehouseFilters,
        onApply: @escaping (WarehouseFilters) -> Void,
        onReset: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.availableCategories = availableCategories
        self.initial = initial
        self.onApply = onApply
        self.onReset = onReset
        self.onCancel = onCancel
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    sortSection
                    expirationSection
                    smartFiltersSection
                    categoriesSection
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }


    private var header: some View {
        SheetHeader(title: "Фильтры", onClose: onCancel)
    }

    private var sortSection: some View {
        sectionContainer(title: "Сортировка") {
            VStack(spacing: 8) {
                ForEach(WarehouseSortOption.allCases) { option in
                    selectableRow(
                        title: option.title,
                        isSelected: draft.sort == option
                    ) {
                        draft.sort = option
                    }
                }
            }
        }
    }

    private var expirationSection: some View {
        sectionContainer(title: "Срок годности") {
            flowLayout(items: ExpirationFilter.allCases) { filter in
                GlassChip(
                    title: filter.title,
                    isSelected: draft.expirationSet.contains(filter)
                ) {
                    toggleExpiration(filter)
                }
            }
        }
    }

    private var smartFiltersSection: some View {
        sectionContainer(title: "Умные фильтры") {
            flowLayout(items: SmartFilter.allCases) { filter in
                GlassChip(
                    title: filter.title,
                    isSelected: draft.smartFilters.contains(filter)
                ) {
                    toggleSmart(filter)
                }
            }
        }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        if !availableCategories.isEmpty {
            sectionContainer(title: "Категории") {
                flowLayout(items: availableCategories) { name in
                    GlassChip(
                        title: name,
                        isSelected: draft.selectedCategories.contains(name)
                    ) {
                        toggleCategory(name)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            GlassPillButton("Применить", role: .primary) {
                onApply(draft)
            }
            GlassPillButton("Сбросить", role: .secondary) {
                draft = .none
                onReset()
            }
        }
        .padding(.top, 8)
    }


    private func toggleCategory(_ name: String) {
        AppHaptics.selection()
        if draft.selectedCategories.contains(name) {
            draft.selectedCategories.remove(name)
        } else {
            draft.selectedCategories.insert(name)
        }
    }

    private func toggleSmart(_ filter: SmartFilter) {
        AppHaptics.selection()
        if draft.smartFilters.contains(filter) {
            draft.smartFilters.remove(filter)
        } else {
            draft.smartFilters.insert(filter)
        }
    }

    private func toggleExpiration(_ filter: ExpirationFilter) {
        AppHaptics.selection()
        if draft.expirationSet.contains(filter) {
            draft.expirationSet.remove(filter)
        } else {
            draft.expirationSet.insert(filter)
        }
    }

    @ViewBuilder
    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 14)
            content()
        }
    }

    private func selectableRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.selection()
            action()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .semiBold, size: 15)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .appAnimation(AppAnimation.snap, value: isSelected)
    }

    @ViewBuilder
    private func flowLayout<Item: Hashable, Content: View>(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                content(item)
            }
        }
    }
}

#Preview {
    WarehouseFiltersSheet(
        availableCategories: ["еда", "напитки", "техника", "декор"],
        initial: .none,
        onApply: { _ in },
        onReset: {},
        onCancel: {}
    )
}
