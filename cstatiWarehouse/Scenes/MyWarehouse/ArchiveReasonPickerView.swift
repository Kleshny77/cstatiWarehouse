//
//  ArchiveReasonPickerView.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

/// Результат списания: сколько единиц, причина и текстовое пояснение при необходимости.
struct ArchiveDecision: Equatable {
    let quantity: Int
    let reason: ArchiveReason
    let detail: String
}

struct ArchiveReasonPickerView: View {

    // MARK: Properties

    let itemName: String
    let availableQuantity: Int
    let onConfirm: (ArchiveDecision) -> Void
    let onCancel: () -> Void

    @State private var quantity: Int
    @State private var selectedReason: ArchiveReason = .expired
    @State private var detail: String = ""
    @FocusState private var isDetailFocused: Bool

    // MARK: Lifecycle

    init(
        itemName: String,
        availableQuantity: Int,
        onConfirm: @escaping (ArchiveDecision) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.itemName = itemName
        self.availableQuantity = max(1, availableQuantity)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _quantity = State(initialValue: max(1, availableQuantity))
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    quantitySection
                    reasonList
                    if selectedReason.requiresDetail {
                        detailField
                    }
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .appAnimation(AppAnimation.smooth, value: selectedReason)
    }

    // MARK: UI Configuration

    private var header: some View {
        VStack(spacing: 8) {
            Text("Списать со склада?")
                .foregroundStyle(.white.opacity(0.95))
                .font(font: .bold, size: 20)
                .multilineTextAlignment(.center)
            Text("«\(itemName)» — укажите количество и причину. Запись появится в истории.")
                .foregroundStyle(.white.opacity(0.6))
                .font(font: .semiBold, size: 13)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Количество")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(font: .semiBold, size: 14)
                Spacer()
                Text("доступно: \(availableQuantity)")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(font: .semiBold, size: 12)
            }

            HStack(spacing: 12) {
                stepperButton(symbol: "minus", isEnabled: quantity > 1) {
                    if quantity > 1 {
                        AppHaptics.selection()
                        quantity -= 1
                    }
                }

                Text("\(quantity)")
                    .font(font: .bold, size: 22)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: quantity)

                stepperButton(symbol: "plus", isEnabled: quantity < availableQuantity) {
                    if quantity < availableQuantity {
                        AppHaptics.selection()
                        quantity += 1
                    }
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 6)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func stepperButton(symbol: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.35))
                .frame(width: 44, height: 44)
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }

    private var reasonList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Причина")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 14)

            VStack(spacing: 10) {
                ForEach(ArchiveReason.allCases) { reason in
                    reasonRow(reason)
                }
            }
        }
    }

    private func reasonRow(_ reason: ArchiveReason) -> some View {
        let isSelected = reason == selectedReason
        return Button {
            AppHaptics.selection()
            selectedReason = reason
            if !reason.requiresDetail {
                detail = ""
                isDetailFocused = false
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: reason.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24)
                Text(reason.title)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .semiBold, size: 15)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 18, weight: .semibold))
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
    }

    private var detailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedReason.detailPlaceholder ?? "Подробности")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 14)
            TextField(
                "",
                text: $detail,
                prompt: Text(selectedReason.detailPlaceholder ?? "")
                    .foregroundColor(.white.opacity(0.4))
                    .font(font: .semiBold, size: 14)
            )
            .focused($isDetailFocused)
            .tint(.white.opacity(0.8))
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .semiBold, size: 14)
            .padding(.horizontal, 17)
            .frame(height: 47)
            .appGlass()
            .autocapitalization(.sentences)
        }
        .transition(.opacity)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                submit()
            } label: {
                Text(confirmButtonTitle)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 15)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            Button {
                onCancel()
            } label: {
                Text("Отмена")
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

    private var canSubmit: Bool {
        guard quantity > 0, quantity <= availableQuantity else { return false }
        if selectedReason.requiresDetail,
           detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    private var confirmButtonTitle: String {
        if quantity == availableQuantity {
            return "Списать всё"
        }
        return "Списать \(quantity) шт"
    }

    private func submit() {
        guard canSubmit else { return }
        AppHaptics.impact(.medium)
        onConfirm(
            ArchiveDecision(
                quantity: quantity,
                reason: selectedReason,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }
}

#Preview {
    ArchiveReasonPickerView(
        itemName: "Водка «Русский стандарт»",
        availableQuantity: 10,
        onConfirm: { _ in },
        onCancel: { }
    )
}
