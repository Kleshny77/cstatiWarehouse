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
    /// При «Использовано на мероприятии» — выбранное мероприятие организации (если есть).
    let eventID: UUID?

    init(quantity: Int, reason: ArchiveReason, detail: String, eventID: UUID? = nil) {
        self.quantity = quantity
        self.reason = reason
        self.detail = detail
        self.eventID = eventID
    }
}

struct ArchiveReasonPickerView: View {

    // MARK: Properties

    let itemName: String
    let availableQuantity: Int
    /// Мероприятия активной организации — подсказки для причины «на мероприятии».
    var orgEvents: [OrgEvent] = []
    let onConfirm: (ArchiveDecision) -> Void
    let onCancel: () -> Void

    @State private var quantity: Int
    @State private var selectedReason: ArchiveReason = .expired
    @State private var detail: String = ""
    @State private var selectedEventID: UUID?
    @FocusState private var isDetailFocused: Bool

    // MARK: Lifecycle

    init(
        itemName: String,
        availableQuantity: Int,
        orgEvents: [OrgEvent] = [],
        onConfirm: @escaping (ArchiveDecision) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.itemName = itemName
        self.availableQuantity = max(1, availableQuantity)
        self.orgEvents = orgEvents
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
                    if selectedReason == .usedAtEvent, !orgEvents.isEmpty {
                        eventsSection
                    }
                    detailSection
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
            if reason != .usedAtEvent {
                selectedEventID = nil
            }
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
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Мероприятие")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orgEvents) { event in
                        eventChip(event)
                    }
                }
                .padding(.vertical, 2)
            }
            Text("Или укажите название в поле ниже")
                .font(font: .semiBold, size: 11)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func eventChip(_ event: OrgEvent) -> some View {
        let isSelected = selectedEventID == event.id
        return Button {
            AppHaptics.selection()
            selectedEventID = isSelected ? nil : event.id
            if selectedEventID != nil {
                detail = ""
            }
        } label: {
            Text(event.name)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                )
                .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Поля подробностей в зависимости от причины.
    private var detailSection: some View {
        Group {
            if selectedReason == .usedAtEvent {
                if orgEvents.isEmpty {
                    detailField
                } else if selectedEventID == nil {
                    detailField
                } else {
                    optionalCommentField
                }
            } else if selectedReason.requiresDetail {
                detailField
            }
        }
    }

    private var optionalCommentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий (необязательно)")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 14)
            TextField(
                "",
                text: $detail,
                prompt: Text("Напр. подразделение или заметка")
                    .foregroundColor(.white.opacity(0.4))
                    .font(font: .semiBold, size: 14)
            )
            .focused($isDetailFocused)
            .tint(.white.opacity(0.8))
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .semiBold, size: 14)
            .padding(.horizontal, 17)
            .frame(height: 47)
            .frame(maxWidth: .infinity)
            .appGlass()
            .autocapitalization(.sentences)
        }
        .transition(.opacity)
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
            .frame(maxWidth: .infinity)
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 8)
    }

    // MARK: Private Methods

    private var canSubmit: Bool {
        guard quantity > 0, quantity <= availableQuantity else { return false }
        if selectedReason == .usedAtEvent {
            if selectedEventID != nil { return true }
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }
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
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let eventID = selectedReason == .usedAtEvent ? selectedEventID : nil
        onConfirm(
            ArchiveDecision(
                quantity: quantity,
                reason: selectedReason,
                detail: trimmedDetail,
                eventID: eventID
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
