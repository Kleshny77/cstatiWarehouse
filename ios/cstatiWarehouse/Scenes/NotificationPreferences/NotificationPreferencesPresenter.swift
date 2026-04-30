//
//  NotificationPreferencesPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

@Observable
final class NotificationPreferencesPresenter {

    enum State: Equatable {
        case loading
        case loaded(NotificationPreferences)
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var isSaving: Bool = false
    var savingErrorMessage: String?

    private let service: NotificationPreferencesServiceProtocol

    init(service: NotificationPreferencesServiceProtocol) {
        self.service = service
    }

    func onAppear() {
        load()
    }

    func reload() {
        load()
    }

    func toggle(level: ExpirationLevel, enabled: Bool) {
        guard case .loaded(var prefs) = state else { return }
        prefs.setEnabled(enabled, for: level)
        state = .loaded(prefs)
        var patch = NotificationPreferencesPatch()
        switch level {
        case .earlyWarning: patch.earlyWarningEnabled = enabled
        case .actionRequired: patch.actionRequiredEnabled = enabled
        case .critical: patch.criticalEnabled = enabled
        case .expired: patch.expiredEnabled = enabled
        }
        save(patch: patch)
    }

    func updateQuietHours(startMinute: Int, endMinute: Int) {
        guard case .loaded(var prefs) = state else { return }
        prefs.quietHoursStartMinute = startMinute
        prefs.quietHoursEndMinute = endMinute
        state = .loaded(prefs)
        var patch = NotificationPreferencesPatch()
        patch.quietHoursStartMinute = startMinute
        patch.quietHoursEndMinute = endMinute
        save(patch: patch)
    }

    func updateTimezone(_ tz: String) {
        guard case .loaded(var prefs) = state else { return }
        prefs.timezone = tz
        state = .loaded(prefs)
        var patch = NotificationPreferencesPatch()
        patch.timezone = tz
        save(patch: patch)
    }

    // MARK: - Private

    private func load() {
        state = .loading
        service.fetch { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let prefs):
                self.state = .loaded(prefs)
            case .failure(let err):
                self.state = .failed(err.message)
            }
        }
    }

    private func save(patch: NotificationPreferencesPatch) {
        isSaving = true
        savingErrorMessage = nil
        service.update(patch: patch) { [weak self] result in
            guard let self else { return }
            self.isSaving = false
            switch result {
            case .success(let updated):
                self.state = .loaded(updated)
            case .failure(let err):
                self.savingErrorMessage = err.message
            }
        }
    }
}
