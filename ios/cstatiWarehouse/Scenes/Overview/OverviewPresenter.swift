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
    func expiringItemTapped(_ item: ExpiringItem)
    func routePlanningTapped()
    func dismissPassiveNotice()
}

@Observable
final class OverviewPresenter: OverviewPresenterProtocol {

    var interactor: OverviewInteractorInputProtocol?
    var router: OverviewRouterProtocol?

    var isLoading: Bool = false
    var metrics: DashboardMetrics?
    var overviewSnapshot: OverviewAnalyticsSnapshot?
    var organizationTitle: String = ""
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

    func expiringItemTapped(_ item: ExpiringItem) {
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
        metrics = nil
        overviewSnapshot = nil
        organizationTitle = ""
        isLoading = false
        passiveNoticeMessage = nil
        emptyOrganizationMessage = "Выберите организацию на вкладке «Мой склад»."
        finishRefreshIfNeeded()
    }

    func analyticsCacheHit(_ metrics: DashboardMetrics, organizationTitle: String) {
        errorMessage = nil
        self.metrics = metrics
        self.organizationTitle = organizationTitle
        self.emptyOrganizationMessage = nil
        self.overviewSnapshot = nil
    }

    func analyticsLoaded(
        _ metrics: DashboardMetrics,
        snapshot: OverviewAnalyticsSnapshot,
        organizationTitle: String
    ) {
        passiveNoticeMessage = nil
        self.metrics = metrics
        self.overviewSnapshot = snapshot
        self.organizationTitle = organizationTitle
        isLoading = false
        emptyOrganizationMessage = nil
        finishRefreshIfNeeded()
    }

    func loadFailed(message: String) {
        if metrics != nil {
            passiveNoticeMessage = message
        } else {
            errorMessage = message
        }
        isLoading = false
        finishRefreshIfNeeded()
    }
}
