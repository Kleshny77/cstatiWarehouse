//
//  ReservationsView.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import SwiftUI

struct ReservationsView: View {
    @Bindable var presenter: ReservationsPresenter
    @State private var cancellingReservation: ItemReservation?
    @State private var cancelReasonText: String = ""

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 0) {
                header
                content
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { presenter.onAppear() }
        .sheet(isPresented: $presenter.isCreatePresented) {
            CreateReservationSheet(presenter: presenter)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(item: $cancellingReservation) { reservation in
            CancelReservationSheet(
                reservation: reservation,
                eventName: presenter.eventName(for: reservation.eventID),
                reasonText: $cancelReasonText,
                onConfirm: {
                    presenter.cancel(reservation, reason: cancelReasonText)
                    cancelReasonText = ""
                    cancellingReservation = nil
                },
                onCancel: {
                    cancelReasonText = ""
                    cancellingReservation = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") { presenter.transientErrorMessage = nil }
        } message: {
            if let m = presenter.transientErrorMessage { Text(m) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Резервирование")
                        .font(font: .bold, size: 22)
                        .defaultTextStyle()
                    Text(presenter.item.name)
                        .font(font: .semiBold, size: 14)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    presenter.presentCreate()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 36, height: 36)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled((presenter.availability?.available ?? presenter.item.quantity) <= 0)
            }
            availabilityCard
            filterChips
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var availabilityCard: some View {
        if let info = presenter.availability {
            HStack(spacing: 0) {
                metric(value: info.total, title: "Всего")
                divider
                metric(value: info.reserved, title: "Резерв")
                divider
                metric(value: info.available, title: "Доступно", highlight: true)
            }
            .padding(.vertical, 14)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func metric(value: Int, title: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(font: .bold, size: 22)
                .foregroundStyle(highlight ? Color.green.opacity(0.95) : .white.opacity(0.95))
            Text(title)
                .font(font: .semiBold, size: 12)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 30)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReservationsPresenter.Filter.allCases, id: \.self) { filter in
                    Button {
                        presenter.filter = filter
                    } label: {
                        Text(filter.title)
                            .font(font: .semiBold, size: 13)
                            .foregroundStyle(presenter.filter == filter ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(
                                    presenter.filter == filter
                                        ? Color.white.opacity(0.18)
                                        : Color.white.opacity(0.06)
                                )
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch presenter.state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            failedState(message: message)
        case .loaded:
            if presenter.reservations.isEmpty {
                emptyState
            } else {
                reservationsList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
            Text(presenter.filter == .all ? "Резервирований пока нет" : "Нет броней с таким статусом")
                .font(font: .semiBold, size: 15)
                .foregroundStyle(.white.opacity(0.8))
            if presenter.filter == .all {
                Button {
                    presenter.presentCreate()
                } label: {
                    Text("Создать первое")
                        .font(font: .semiBold, size: 14)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .appGlass(in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text(message)
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                presenter.reload()
            } label: {
                Text("Повторить")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .appGlass(in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reservationsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(presenter.reservations, id: \.id) { reservation in
                    reservationCard(reservation)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func reservationCard(_ r: ItemReservation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(presenter.eventName(for: r.eventID) ?? "Без мероприятия")
                            .font(font: .semiBold, size: 14)
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                    Text("\(r.quantity) ед. · \(presenter.displayName(for: r.reservedByUserID))")
                        .font(font: .semiBold, size: 12)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                statusBadge(r.status)
            }

            if !r.notes.isEmpty {
                Text(r.notes)
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                Text(Self.relativeFormatter.localizedString(for: r.reservedAt, relativeTo: .now))
                if let exp = r.expiresAt {
                    Text("· до \(exp.formatted(Self.dateTimeFormat))")
                        .lineLimit(1)
                }
                Spacer()
            }
            .font(font: .semiBold, size: 11)
            .foregroundStyle(.white.opacity(0.55))

            if r.status == .cancelled, !r.cancellationReason.isEmpty {
                Text("Причина отмены: \(r.cancellationReason)")
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(Color.red.opacity(0.85))
            }

            if r.status == .active && (presenter.canFulfill(r) || presenter.canCancel(r)) {
                actionsRow(for: r)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusBadge(_ status: ReservationStatus) -> some View {
        Text(status.title)
            .font(font: .semiBold, size: 11)
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Self.statusColor(status).opacity(0.85))
            }
    }

    private func actionsRow(for r: ItemReservation) -> some View {
        HStack(spacing: 8) {
            if presenter.canFulfill(r) {
                Button {
                    presenter.fulfill(r)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Выполнить")
                    }
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule().fill(Color.green.opacity(0.7))
                    }
                }
                .buttonStyle(.pressable)
            }
            if presenter.canCancel(r) {
                Button {
                    cancelReasonText = ""
                    cancellingReservation = r
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Отменить")
                    }
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule().fill(Color.red.opacity(0.65))
                    }
                }
                .buttonStyle(.pressable)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.transientErrorMessage != nil },
            set: { if !$0 { presenter.transientErrorMessage = nil } }
        )
    }

    private static func statusColor(_ status: ReservationStatus) -> Color {
        switch status {
        case .active:    return Color.blue
        case .fulfilled: return Color.green
        case .cancelled: return Color.gray
        case .expired:   return Color.orange
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f
    }()

    private static let dateTimeFormat = Date.FormatStyle()
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .hour(.defaultDigits(amPM: .omitted))
        .minute(.twoDigits)
}

// MARK: - Create reservation sheet

private struct CreateReservationSheet: View {
    @Bindable var presenter: ReservationsPresenter
    @State private var newEventDraft: String = ""

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SheetHeader(
                        title: "Новая бронь",
                        subtitle: "Под какое мероприятие резервируем",
                        onClose: { presenter.dismissCreate() }
                    )

                    sectionTitle("Количество")
                    quantityStepper

                    eventSection

                    sectionTitle("Срок действия")
                    expirySection

                    sectionTitle("Комментарий (необязательно)")
                    glassTextEditor(text: $presenter.draftNotes, placeholder: "Например: забрать к 12:00, вернуть после ивента", minHeight: 60)

                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $presenter.isNewEventSheetPresented) {
            newEventSheet
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(font: .semiBold, size: 12)
            .foregroundStyle(.white.opacity(0.6))
    }

    private var quantityStepper: some View {
        HStack(spacing: 12) {
            Button {
                if presenter.draftQuantity > 1 { presenter.draftQuantity -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(presenter.draftQuantity <= 1)

            Text("\(presenter.draftQuantity)")
                .font(font: .bold, size: 22)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .appGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                if presenter.draftQuantity < presenter.maxQuantityForDraft {
                    presenter.draftQuantity += 1
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(presenter.draftQuantity >= presenter.maxQuantityForDraft)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("Максимум: \(presenter.maxQuantityForDraft)")
                .font(font: .semiBold, size: 11)
                .foregroundStyle(.white.opacity(0.55))
                .offset(y: 22)
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Мероприятие")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    AppHaptics.impact(.light)
                    newEventDraft = ""
                    presenter.isNewEventSheetPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Новое")
                            .font(font: .semiBold, size: 13)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .appGlass(in: Capsule())
                }
                .buttonStyle(.pressable)
            }

            eventChipsFlow
        }
    }

    private var eventChipsFlow: some View {
        FlowLayout(spacing: 8) {
            GlassChip(title: "Без мероприятия", isSelected: presenter.draftEventID == nil) {
                presenter.draftEventID = nil
            }
            ForEach(presenter.availableEvents) { event in
                GlassChip(title: event.name, isSelected: presenter.draftEventID == event.id) {
                    presenter.draftEventID = event.id
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var newEventSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(
                title: "Новое мероприятие",
                subtitle: "Будет доступно всем участникам организации",
                onClose: { presenter.isNewEventSheetPresented = false }
            )

            GlassTextField(
                title: "Название",
                placeholder: "например, корпоратив 5 мая",
                text: $newEventDraft,
                useFullWidth: true
            )

            HStack(spacing: 10) {
                GlassPillButton("Отмена", role: .secondary) {
                    presenter.isNewEventSheetPresented = false
                }
                GlassPillButton(
                    "Создать",
                    role: .primary,
                    isEnabled: !newEventDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    presenter.createNewEvent(name: newEventDraft)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .presentationDetents([.height(298)])
        .presentationDragIndicator(.visible)
        .presentationBackground(SheetPresentationChrome.organizationManagementGradient)
    }

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $presenter.draftHasExpiry) {
                Text("Установить срок действия")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .tint(.green)
            if presenter.draftHasExpiry {
                DatePicker(
                    "",
                    selection: $presenter.draftExpiresAt,
                    in: Date().addingTimeInterval(60)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.colorScheme, .dark)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            }
        }
        .padding(.vertical, 6)
    }

    private func glassTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.45)))
            .font(font: .semiBold, size: 14)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .appGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func glassTextEditor(text: Binding<String>, placeholder: String, minHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }
            TextEditor(text: text)
                .font(font: .semiBold, size: 14)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: minHeight)
        }
        .appGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var submitButton: some View {
        Button {
            presenter.submitCreate()
        } label: {
            HStack(spacing: 8) {
                if presenter.isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(presenter.isSubmitting ? "Создаём…" : "Создать бронь")
                    .font(font: .semiBold, size: 16)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.85))
            }
        }
        .buttonStyle(.pressable)
        .disabled(presenter.isSubmitting || presenter.maxQuantityForDraft <= 0)
        .padding(.top, 8)
    }
}

// MARK: - Cancel reservation sheet

private struct CancelReservationSheet: View {
    let reservation: ItemReservation
    let eventName: String?
    @Binding var reasonText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    title: "Отменить бронь",
                    onClose: onCancel
                )

                Text("\(reservation.quantity) ед.\(eventName.map { " · \($0)" } ?? "")")
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(.white.opacity(0.7))

                Text("Причина отмены (необязательно)")
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white.opacity(0.6))

                ZStack(alignment: .topLeading) {
                    if reasonText.isEmpty {
                        Text("Например: заказ отменён клиентом")
                            .font(font: .semiBold, size: 14)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                    }
                    TextEditor(text: $reasonText)
                        .font(font: .semiBold, size: 14)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 80)
                }
                .appGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer(minLength: 0)

                Button {
                    onConfirm()
                } label: {
                    Text("Подтвердить отмену")
                        .font(font: .semiBold, size: 16)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(0.85))
                        }
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}
