//
//  LoginPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct LoginPresenterTests {
    @Test
    func loginButtonTapped_delegatesToInteractor() {
        let (sut, interactor, router) = makeSUT()
        sut.loginButtonTapped(email: "a@b.c", password: "secret")
        #expect(interactor.loginCalls.count == 1)
        #expect(interactor.loginCalls[0].0 == "a@b.c")
        #expect(interactor.loginCalls[0].1 == "secret")
        #expect(router.navigateToMainCount == 0)
    }

    @Test
    func registerButtonTapped_navigatesToRegister() {
        let (sut, _, router) = makeSUT()
        sut.registerButtonTapped()
        #expect(router.navigateToRegisterCount == 1)
    }

    @Test
    func telegramSecondTapWhileOAuthIgnored() {
        let (sut, interactor, _) = makeSUT()
        sut.telegramLoginButtonTapped()
        sut.telegramLoginButtonTapped()
        #expect(interactor.telegramLoginCallCount == 1)
    }

    @Test
    func loginSuccess_navigatesToMain_andClearsOAuthFlag() {
        let (sut, _, router) = makeSUT()
        sut.telegramLoginButtonTapped()
        #expect(sut.isOAuthLoginInProgress)

        sut.loginSuccess()

        #expect(sut.isOAuthLoginInProgress == false)
        #expect(router.navigateToMainCount == 1)
    }

    @Test
    func loginFailure_setsMessage_andClearsOAuthFlag() {
        let (sut, _, _) = makeSUT()
        sut.googleLoginButtonTapped()
        sut.loginFailure(error: "Ошибка")
        #expect(sut.errorMessage == "Ошибка")
        #expect(sut.isOAuthLoginInProgress == false)
    }

    // MARK: - Test doubles

    private final class LoginInteractorFake: LoginInteractorInputProtocol {
        var loginCalls: [(String, String)] = []
        var telegramLoginCallCount = 0
        var googleLoginCallCount = 0

        func login(email: String, password: String) {
            loginCalls.append((email, password))
        }

        func loginWithTelegram() {
            telegramLoginCallCount += 1
        }

        func loginWithGoogle() {
            googleLoginCallCount += 1
        }
    }

    private final class LoginRouterSpy: LoginRouterProtocol {
        var navigateToMainCount = 0
        var navigateToRegisterCount = 0

        func navigateToMain() {
            navigateToMainCount += 1
        }

        func navigateToRegister() {
            navigateToRegisterCount += 1
        }
    }

    private func makeSUT() -> (LoginPresenter, LoginInteractorFake, LoginRouterSpy) {
        let interactor = LoginInteractorFake()
        let router = LoginRouterSpy()
        let presenter = LoginPresenter()
        presenter.interactor = interactor
        presenter.router = router
        return (presenter, interactor, router)
    }
}
