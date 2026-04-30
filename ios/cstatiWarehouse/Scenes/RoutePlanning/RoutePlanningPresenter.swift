//
//  RoutePlanningPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation

protocol RoutePlanningPresenterProtocol: AnyObject {
    func viewDidLoad()
    func dismissTapped()
    func buildRouteTapped()
    func setQuantity(itemID: UUID, value: Int)
    func destinationAddressChanged()
    func startAddressChanged()
}

@Observable
final class RoutePlanningPresenter: RoutePlanningPresenterProtocol {

    var interactor: RoutePlanningInteractorInputProtocol?
    var router: RoutePlanningRouterProtocol?

    var rows: [RoutePlanningItemRow] = []
    var selection: [UUID: Int] = [:]
    var destinationAddress: String = ""
    var startAddress: String = ""
    var transport: RouteTransportPreference = .automobile

    var availableEvents: [OrgEvent] = []
    var selectedEventID: UUID?
    var isApplyingEventReservations: Bool = false
    var eventApplyHint: String?

    var builtModel: RoutePlanningMapModel?
    var isLoadingItems: Bool = false
    var isBuildingRoute: Bool = false
    var errorMessage: String?

    private(set) var destinationGeocodePreviewStatus: AddressGeocodeInlineStatus = .hidden
    private(set) var startGeocodePreviewStatus: AddressGeocodeInlineStatus = .hidden

    private let geocoder: AddressGeocoderProtocol
    private let addressGeocodeDebounce: TimeInterval

    private var destinationFingerprint: String?
    private var startFingerprint: String?
    private var destinationWorkItem: DispatchWorkItem?
    private var startWorkItem: DispatchWorkItem?

    private var didRunInitialViewLoad: Bool = false

    init(geocoder: AddressGeocoderProtocol = AddressGeocoder(), addressGeocodeDebounce: TimeInterval = 0.45) {
        self.geocoder = geocoder
        self.addressGeocodeDebounce = addressGeocodeDebounce
    }

    func viewDidLoad() {
        if !didRunInitialViewLoad {
            didRunInitialViewLoad = true
            isLoadingItems = true
            errorMessage = nil
            builtModel = nil
            interactor?.loadPickupItems()
            interactor?.loadEvents()
        }
        destinationAddressChanged()
        startAddressChanged()
    }

    func selectEvent(_ id: UUID?) {
        selectedEventID = id
        eventApplyHint = nil
        guard let id else {
            // Clear selection when "no event" chip tapped.
            for key in selection.keys {
                selection[key] = 0
            }
            return
        }
        isApplyingEventReservations = true
        interactor?.applyEventReservations(eventID: id)
    }

    func dismissTapped() {
        router?.dismiss()
    }

    func destinationAddressChanged() {
        destinationWorkItem?.cancel()
        let trimmed = destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if destinationGeocodePreviewStatus != .hidden {
                destinationGeocodePreviewStatus = .hidden
            }
            destinationFingerprint = nil
            return
        }

        if case .ok = destinationGeocodePreviewStatus,
           destinationFingerprint == trimmed {
            return
        }

        if let fp = destinationFingerprint, fp != trimmed {
            destinationFingerprint = nil
        }

        switch destinationGeocodePreviewStatus {
        case .idleTyping:
            break
        default:
            destinationGeocodePreviewStatus = .idleTyping
        }

        let work = DispatchWorkItem { [weak self] in
            self?.runDestinationGeocode(trimmed: trimmed)
        }
        destinationWorkItem = work
        schedule(work: work)
    }

    func startAddressChanged() {
        startWorkItem?.cancel()
        let trimmed = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if startGeocodePreviewStatus != .hidden {
                startGeocodePreviewStatus = .hidden
            }
            startFingerprint = nil
            return
        }

        if case .ok = startGeocodePreviewStatus,
           startFingerprint == trimmed {
            return
        }

        if let fp = startFingerprint, fp != trimmed {
            startFingerprint = nil
        }

        switch startGeocodePreviewStatus {
        case .idleTyping:
            break
        default:
            startGeocodePreviewStatus = .idleTyping
        }

        let work = DispatchWorkItem { [weak self] in
            self?.runStartGeocode(trimmed: trimmed)
        }
        startWorkItem = work
        schedule(work: work)
    }

    private func schedule(work: DispatchWorkItem) {
        if addressGeocodeDebounce <= 0 {
            DispatchQueue.main.async(execute: work)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + addressGeocodeDebounce, execute: work)
        }
    }

    private func runDestinationGeocode(trimmed: String) {
        destinationGeocodePreviewStatus = .checking
        geocoder.geocodeAddress(trimmed) { [weak self] result in
            guard let self else { return }
            let current = self.destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard current == trimmed else { return }
            switch result {
            case .success(let coord):
                self.destinationFingerprint = trimmed
                self.destinationGeocodePreviewStatus = .ok(latitude: coord.latitude, longitude: coord.longitude)
            case .failure(let error):
                self.destinationFingerprint = nil
                self.destinationGeocodePreviewStatus = .failed(GeocodingUserMessage.message(for: error))
            }
        }
    }

    private func runStartGeocode(trimmed: String) {
        startGeocodePreviewStatus = .checking
        geocoder.geocodeAddress(trimmed) { [weak self] result in
            guard let self else { return }
            let current = self.startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard current == trimmed else { return }
            switch result {
            case .success(let coord):
                self.startFingerprint = trimmed
                self.startGeocodePreviewStatus = .ok(latitude: coord.latitude, longitude: coord.longitude)
            case .failure(let error):
                self.startFingerprint = nil
                self.startGeocodePreviewStatus = .failed(GeocodingUserMessage.message(for: error))
            }
        }
    }

    func buildRouteTapped() {
        errorMessage = nil
        builtModel = nil

        let destTrim = destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destTrim.isEmpty else {
            errorMessage = "Укажите адрес мероприятия."
            return
        }

        guard destinationFingerprint == destTrim,
              case .ok = destinationGeocodePreviewStatus else {
            errorMessage = blockingGeocodeMessage(for: destinationGeocodePreviewStatus, role: "мероприятия")
            return
        }

        let startTrim = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !startTrim.isEmpty {
            guard startFingerprint == startTrim,
                  case .ok = startGeocodePreviewStatus else {
                errorMessage = blockingGeocodeMessage(for: startGeocodePreviewStatus, role: "старта")
                return
            }
        }

        isBuildingRoute = true
        interactor?.buildRoute(
            selection: selection,
            destinationAddress: destinationAddress,
            startAddress: startTrim.isEmpty ? nil : startAddress,
            transport: transport
        )
    }

    private func blockingGeocodeMessage(for status: AddressGeocodeInlineStatus, role: String) -> String {
        switch status {
        case .checking:
            return "Подождите: проверяем адрес \(role) на карте."
        case .failed:
            return "Исправьте адрес \(role) по подсказке под полем."
        case .idleTyping:
            return "Проверка адреса \(role) ещё не завершена. Подождите или допишите адрес."
        default:
            return "Дождитесь, пока адрес \(role) появится на карте ниже."
        }
    }

    func setQuantity(itemID: UUID, value: Int) {
        guard let row = rows.first(where: { $0.id == itemID }) else { return }
        let clamped = min(max(0, value), row.maxQuantity)
        selection[itemID] = clamped
    }
}

extension RoutePlanningPresenter: RoutePlanningInteractorOutputProtocol {

    func pickupItemsLoaded(_ rows: [RoutePlanningItemRow]) {
        isLoadingItems = false
        self.rows = rows
        var next: [UUID: Int] = [:]
        for r in rows {
            next[r.id] = selection[r.id] ?? 0
        }
        selection = next
    }

    func eventsLoaded(_ events: [OrgEvent]) {
        availableEvents = events
    }

    func eventReservationsApplied(selection: [UUID: Int], skippedNames: [String]) {
        isApplyingEventReservations = false
        // Reset all to zero, then apply
        var next: [UUID: Int] = [:]
        for r in rows {
            next[r.id] = selection[r.id] ?? 0
        }
        self.selection = next
        let appliedCount = selection.values.filter { $0 > 0 }.count
        if appliedCount == 0 {
            eventApplyHint = "Под это мероприятие нет активных броней."
        } else {
            eventApplyHint = "Подставлено позиций: \(appliedCount)."
        }
    }

    func routePlanningFailed(message: String) {
        errorMessage = message
        isBuildingRoute = false
        isApplyingEventReservations = false
    }

    func routePlanningBuilt(model: RoutePlanningMapModel) {
        builtModel = model
        isBuildingRoute = false
    }
}
