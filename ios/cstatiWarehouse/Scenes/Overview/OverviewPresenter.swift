//
//  OverviewPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol OverviewPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refreshAsync() async
    func categoryRowTapped(_ row: OverviewCategoryRow)
    func routePlanningTapped()
    func dismissPassiveNotice()
}

@Observable
final class OverviewPresenter: OverviewPresenterProtocol {

    var interactor: OverviewInteractorInputProtocol?
    var router: OverviewRouterProtocol?

    var isLoading: Bool = false
    var snapshot: OverviewAnalyticsSnapshot?
    var errorMessage: String?
    var passiveNoticeMessage: String?
    var emptyOrganizationMessage: String?

    var isRoutePlanningPresented: Bool = false

    private var pendingRefreshContinuation: CheckedContinuation<Void, Never>?

    func viewDidLoad() {
        load()
    }

    func refreshAsync() async {
        await withCheckedContinuation { continuation in
            pendingRefreshContinuation = continuation
            isLoading = true
            errorMessage = nil
            passiveNoticeMessage = nil
            emptyOrganizationMessage = nil
            interactor?.loadAnalytics()
        }
    }

    func categoryRowTapped(_ row: OverviewCategoryRow) {
        guard row.canNavigateToWarehouse else { return }
        router?.openWarehouseFiltered(byCategory: row.filterKey)
    }

    func routePlanningTapped() {
        isRoutePlanningPresented = true
    }

    func dismissPassiveNotice() {
        passiveNoticeMessage = nil
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        passiveNoticeMessage = nil
        emptyOrganizationMessage = nil
        interactor?.loadAnalytics()
    }

    private func finishRefreshIfNeeded() {
        pendingRefreshContinuation?.resume()
        pendingRefreshContinuation = nil
    }
}

extension OverviewPresenter: OverviewInteractorOutputProtocol {

    func noActiveOrganization() {
        snapshot = nil
        isLoading = false
        passiveNoticeMessage = nil
        emptyOrganizationMessage = "Выберите организацию на вкладке «Мой склад»."
        finishRefreshIfNeeded()
    }

    func analyticsLoaded(_ snapshot: OverviewAnalyticsSnapshot) {
        passiveNoticeMessage = nil
        self.snapshot = snapshot
        isLoading = false
        emptyOrganizationMessage = nil
        finishRefreshIfNeeded()
    }

    func loadFailed(message: String) {
        if snapshot != nil {
            passiveNoticeMessage = message
        } else {
            errorMessage = message
        }
        isLoading = false
        finishRefreshIfNeeded()
    }
}
