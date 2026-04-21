//
//  WarehouseFiltersSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct WarehouseFiltersSheet: View {

    // MARK: Properties

    let availableCategories: [String]
    let initial: WarehouseFilters
    let onApply: (WarehouseFilters) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    @State private var draft: WarehouseFilters

    // MARK: Lifecycle

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

    // MARK: UI Configuration

    private var header: some View {
        HStack {
            Text("Фильтры")
                .foregroundStyle(.white.opacity(0.95))
                .font(font: .bold, size: 22)
            Spacer()
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
        }
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
                chip(
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
                chip(
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
                    chip(
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
            Button {
                AppHaptics.impact(.light)
                onApply(draft)
            } label: {
                Text("Применить")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 15)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)

            Button {
                AppHaptics.selection()
                draft = .none
                onReset()
            } label: {
                Text("Сбросить")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(font: .bold, size: 15)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .padding(.top, 8)
    }

    // MARK: Private Methods

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

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.clear)
                )
                .appGlass(in: Capsule())
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

// MARK: - FlowLayout

/// Простой flow-layout для чипов: переносит строки при нехватке ширины.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width + spacing > maxWidth && lineWidth > 0 {
                totalHeight += lineHeight + spacing
                totalWidth = max(totalWidth, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        totalWidth = max(totalWidth, lineWidth)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
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
