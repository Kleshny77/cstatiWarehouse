//
//  NotificationPreferencesPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct NotificationPreferencesPresenterTests {
    @Test
    func toggle_whileLoading_doesNotCallUpdate() async {
        let service = NotificationPreferencesServiceSpy()
        let sut = NotificationPreferencesPresenter(service: service)
        #expect(sut.state == .loading)

        sut.toggle(level: .earlyWarning, enabled: false)

        await Task.yield()
        #expect(service.updateCallCount == 0)
    }

    @Test
    func onAppear_fetchesPreferences() async {
        let service = NotificationPreferencesServiceSpy()
        let sut = NotificationPreferencesPresenter(service: service)

        sut.onAppear()
        await drain()

        if case .loaded = sut.state {
            #expect(service.fetchCallCount == 1)
        } else {
            Issue.record("expected loaded, got \(sut.state)")
        }
    }

    private func drain() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
}

private final class NotificationPreferencesServiceSpy: NotificationPreferencesServiceProtocol {
    private(set) var fetchCallCount = 0
    private(set) var updateCallCount = 0

    func fetch(completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void) {
        fetchCallCount += 1
        DispatchQueue.main.async {
            completion(.success(.defaults()))
        }
    }

    func update(
        patch: NotificationPreferencesPatch,
        completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void
    ) {
        updateCallCount += 1
        DispatchQueue.main.async {
            completion(.success(.defaults()))
        }
    }

    func snooze(
        itemID: UUID,
        duration: TimeInterval,
        completion: @escaping (Result<Void, NotificationPreferencesError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.success(())) }
    }
}
