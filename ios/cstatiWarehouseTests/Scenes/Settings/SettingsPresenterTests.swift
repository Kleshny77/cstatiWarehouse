//
//  SettingsPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
import UIKit
@testable import cstatiWarehouse

@MainActor
struct SettingsPresenterTests {
    @Test
    func viewDidLoad_requestsUser() {
        let (sut, interactor, _) = makeSUT()
        sut.viewDidLoad()
        #expect(interactor.loadUserCallCount == 1)
    }

    @Test
    func saveButtonTapped_withoutChanges_doesNothing() {
        let (sut, interactor, _) = makeSUT()
        let user = User(id: UUID().uuidString, email: "e@e.e", name: "Иван", lastName: "Петров")
        sut.userLoaded(user)

        sut.saveButtonTapped()

        #expect(interactor.updateCalls.isEmpty)
        #expect(sut.isSaving == false)
    }

    @Test
    func saveButtonTapped_emptyName_setsError() {
        let (sut, interactor, _) = makeSUT()
        let user = User(id: UUID().uuidString, email: "e@e.e", name: "Иван", lastName: "Петров")
        sut.userLoaded(user)
        sut.draftName = "   "
        sut.draftLastName = "Сидоров"

        sut.saveButtonTapped()

        #expect(sut.errorMessage == "Имя не может быть пустым")
        #expect(interactor.updateCalls.isEmpty)
    }

    @Test
    func saveButtonTapped_nameChange_callsInteractor() {
        let (sut, interactor, _) = makeSUT()
        let user = User(id: UUID().uuidString, email: "e@e.e", name: "Иван", lastName: "Петров")
        sut.userLoaded(user)
        sut.draftName = "Пётр"

        sut.saveButtonTapped()

        #expect(sut.isSaving == true)
        #expect(interactor.updateCalls.count == 1)
        let call = interactor.updateCalls[0]
        #expect(call.name == "Пётр")
        #expect(call.lastName == nil)
        #expect(call.avatarImage == nil)
        #expect(call.removeAvatar == false)
    }

    @Test
    func hasPendingChanges_falseWhenDraftMatchesUser() {
        let (sut, _, _) = makeSUT()
        let user = User(id: UUID().uuidString, email: "e@e.e", name: "Иван", lastName: "Петров")
        sut.userLoaded(user)
        #expect(sut.hasPendingChanges == false)
    }

    @Test
    func hasPendingChanges_trueWhenLastNameChanges() {
        let (sut, _, _) = makeSUT()
        let user = User(id: UUID().uuidString, email: "e@e.e", name: "Иван", lastName: "Петров")
        sut.userLoaded(user)
        sut.draftLastName = "Сидоров"
        #expect(sut.hasPendingChanges == true)
    }

    // MARK: - Test doubles

    private final class SettingsInteractorFake: SettingsInteractorInputProtocol {
        var loadUserCallCount = 0
        var updateCalls: [(name: String?, lastName: String?, avatarImage: UIImage?, removeAvatar: Bool)] = []

        func loadUser() {
            loadUserCallCount += 1
        }

        func updateProfile(name: String?, lastName: String?, avatarImage: UIImage?, removeAvatar: Bool) {
            updateCalls.append((name, lastName, avatarImage, removeAvatar))
        }

        func logout() {}
    }

    private final class SettingsRouterSpy: SettingsRouterProtocol {
        func navigateToLogin() {}
    }

    private func makeSUT() -> (SettingsPresenter, SettingsInteractorFake, SettingsRouterSpy) {
        let interactor = SettingsInteractorFake()
        let router = SettingsRouterSpy()
        let sut = SettingsPresenter()
        sut.interactor = interactor
        sut.router = router
        return (sut, interactor, router)
    }
}
