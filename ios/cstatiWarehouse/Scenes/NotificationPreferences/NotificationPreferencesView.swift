//
//  NotificationPreferencesView.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

struct NotificationPreferencesView: View {

    @Bindable var presenter: NotificationPreferencesPresenter

    init(presenter: NotificationPreferencesPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()
            content
        }
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { presenter.onAppear() }
        .alert("Не удалось сохранить", isPresented: errorBinding) {
            Button("OK") { presenter.savingErrorMessage = nil }
        } message: {
            if let message = presenter.savingErrorMessage { Text(message) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.state {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let prefs):
            ScrollView {
                VStack(spacing: 20) {
                    headerSubtitle
                    levelsSection(prefs: prefs)
                    quietHoursSection(prefs: prefs)
                    timezoneSection(prefs: prefs)
                    if presenter.isSaving {
                        savingIndicator
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 80)
            }

        case .failed(let message):
            VStack(spacing: 16) {
                Text("Не удалось загрузить настройки")
                    .foregroundStyle(.white.opacity(0.9))
                    .font(font: .bold, size: 17)
                Text(message)
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 14)
                    .multilineTextAlignment(.center)
                Button {
                    presenter.reload()
                } label: {
                    Text("Повторить")
                        .foregroundStyle(.white.opacity(0.95))
                        .font(font: .bold, size: 15)
                        .frame(width: 180, height: 48)
                }
                .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(.pressable)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerSubtitle: some View {
        Text("Выберите, на каких этапах истечения срока годности приходить уведомлениям. Для критичных уведомлений тихие часы игнорируются.")
            .foregroundStyle(.white.opacity(0.7))
            .font(font: .semiBold, size: 13)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func levelsSection(prefs: NotificationPreferences) -> some View {
        VStack(spacing: 12) {
            sectionTitle("Уровни напоминаний")
            VStack(spacing: 0) {
                ForEach(Array(ExpirationLevel.allCases.enumerated()), id: \.element) { index, level in
                    levelRow(level: level, prefs: prefs)
                    if index < ExpirationLevel.allCases.count - 1 {
                        Divider().background(.white.opacity(0.1))
                            .padding(.leading, 16)
                    }
                }
            }
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func levelRow(level: ExpirationLevel, prefs: NotificationPreferences) -> some View {
        let binding = Binding<Bool>(
            get: { prefs.isEnabled(level) },
            set: { newValue in presenter.toggle(level: level, enabled: newValue) }
        )
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(level.localizedTitle)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 15)
                Text(level.localizedHint)
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 12)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func quietHoursSection(prefs: NotificationPreferences) -> some View {
        VStack(spacing: 12) {
            sectionTitle("Тихие часы")
            VStack(spacing: 12) {
                quietHoursPicker(
                    title: "Начало",
                    minute: prefs.quietHoursStartMinute,
                    onChange: { newStart in
                        presenter.updateQuietHours(
                            startMinute: newStart,
                            endMinute: prefs.quietHoursEndMinute
                        )
                    }
                )
                Divider().background(.white.opacity(0.1))
                quietHoursPicker(
                    title: "Конец",
                    minute: prefs.quietHoursEndMinute,
                    onChange: { newEnd in
                        presenter.updateQuietHours(
                            startMinute: prefs.quietHoursStartMinute,
                            endMinute: newEnd
                        )
                    }
                )
            }
            .padding(.vertical, 8)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("В тихие часы доставка обычных уведомлений откладывается. Критичные (за 1 день) приходят всегда.")
                .foregroundStyle(.white.opacity(0.6))
                .font(font: .semiBold, size: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func quietHoursPicker(
        title: String,
        minute: Int,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        let date = Self.dateFromMinute(minute)
        let binding = Binding<Date>(
            get: { date },
            set: { newDate in onChange(Self.minuteFromDate(newDate)) }
        )
        return HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 14)
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
        .padding(.horizontal, 16)
    }

    private func timezoneSection(prefs: NotificationPreferences) -> some View {
        VStack(spacing: 12) {
            sectionTitle("Часовой пояс")
            HStack {
                Text(prefs.timezone)
                    .foregroundStyle(.white.opacity(0.9))
                    .font(font: .semiBold, size: 14)
                Spacer()
                if prefs.timezone != TimeZone.current.identifier {
                    Button {
                        presenter.updateTimezone(TimeZone.current.identifier)
                    } label: {
                        Text("Использовать текущий")
                            .foregroundStyle(.white.opacity(0.95))
                            .font(font: .bold, size: 13)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var savingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.white.opacity(0.85))
            Text("Сохраняем…")
                .foregroundStyle(.white.opacity(0.7))
                .font(font: .semiBold, size: 12)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .extraBold, size: 17)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.savingErrorMessage != nil },
            set: { if !$0 { presenter.savingErrorMessage = nil } }
        )
    }

    // MARK: - Helpers

    private static func dateFromMinute(_ minute: Int) -> Date {
        let clamped = max(0, min(minute, 24 * 60 - 1))
        var components = DateComponents()
        components.hour = clamped / 60
        components.minute = clamped % 60
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func minuteFromDate(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
