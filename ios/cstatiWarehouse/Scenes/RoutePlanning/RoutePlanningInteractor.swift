//
//  RoutePlanningInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation
import MapKit

protocol RoutePlanningInteractorInputProtocol: AnyObject {
    func loadPickupItems()
    func buildRoute(
        selection: [UUID: Int],
        destinationAddress: String,
        startAddress: String?,
        transport: RouteTransportPreference
    )
}

protocol RoutePlanningInteractorOutputProtocol: AnyObject {
    func pickupItemsLoaded(_ rows: [RoutePlanningItemRow])
    func routePlanningFailed(message: String)
    func routePlanningBuilt(model: RoutePlanningMapModel)
}

final class RoutePlanningInteractor: RoutePlanningInteractorInputProtocol {

    weak var presenter: RoutePlanningInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol
    private let geocoder: AddressGeocoderProtocol
    private let routeAssembler: MultiLegDrivingRouteAssembler

    private var cachedRoots: [Item] = []

    init(
        warehouseService: WarehouseServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol,
        geocoder: AddressGeocoderProtocol,
        routeAssembler: MultiLegDrivingRouteAssembler
    ) {
        self.warehouseService = warehouseService
        self.activeOrgStorage = activeOrgStorage
        self.geocoder = geocoder
        self.routeAssembler = routeAssembler
    }

    func loadPickupItems() {
        guard let orgID = activeOrgStorage.activeOrganizationID else {
            presenter?.routePlanningFailed(message: "Нет активной организации.")
            return
        }
        warehouseService.fetchActiveItems(organizationID: orgID, scope: .all) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.presenter?.routePlanningFailed(message: error.message)
                }
            case .success(let items):
                let roots = items.filter { $0.parentItemID == nil && !$0.status.isArchived }
                self.cachedRoots = roots
                let rows = roots.map { item -> RoutePlanningItemRow in
                    RoutePlanningItemRow(
                        id: item.id,
                        name: item.name,
                        categoryName: item.categoryName,
                        maxQuantity: max(item.effectiveQuantityForSort, 0),
                        locationAddress: item.locationAddress
                    )
                }
                .sorted { lhs, rhs in
                    lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
                DispatchQueue.main.async {
                    self.presenter?.pickupItemsLoaded(rows)
                }
            }
        }
    }

    func buildRoute(
        selection: [UUID: Int],
        destinationAddress: String,
        startAddress: String?,
        transport: RouteTransportPreference
    ) {
        let cleanedDestination = destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedDestination.isEmpty else {
            presenter?.routePlanningFailed(message: "Укажите адрес мероприятия.")
            return
        }

        let cleanedStart = startAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let picked = selection.filter { $0.value > 0 }
        guard !picked.isEmpty else {
            presenter?.routePlanningFailed(message: "Выберите хотя бы одну позицию и количество.")
            return
        }

        var groups: [String: (display: String, lines: [(String, Int)])] = [:]

        for (id, qty) in picked {
            guard let root = cachedRoots.first(where: { $0.id == id }) else { continue }
            guard qty > 0, qty <= max(root.effectiveQuantityForSort, 0) else { continue }

            let addrRaw = root.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !addrRaw.isEmpty else {
                presenter?.routePlanningFailed(
                    message: "У позиции «\(root.name)» не указан адрес хранения. Укажите его в карточке позиции."
                )
                return
            }
            let key = addrRaw.lowercased()
            let display = addrRaw

            var bucket = groups[key] ?? (display: display, lines: [])
            bucket.lines.append((root.name, qty))
            groups[key] = bucket
        }

        guard !groups.isEmpty else {
            presenter?.routePlanningFailed(message: "Не удалось сформировать список забора.")
            return
        }

        var pending: [(id: UUID, display: String, lines: [(String, Int)])] = []
        for (_, value) in groups {
            pending.append((id: UUID(), display: value.display, lines: value.lines))
        }

        let uniquePickupAddresses = Self.uniqueOrdered(pending.map(\.display))

        geocodeSerial(addresses: uniquePickupAddresses) { [weak self] pickupCoordsResult in
            guard let self else { return }
            switch pickupCoordsResult {
            case .failure(let failure):
                DispatchQueue.main.async {
                    self.presenter?.routePlanningFailed(message: failure.localizedDescription)
                }
            case .success(let coordByAddress):
                self.finishAfterPickupGeocode(
                    pending: pending,
                    coordByAddress: coordByAddress,
                    destination: cleanedDestination,
                    startRaw: cleanedStart.isEmpty ? nil : cleanedStart,
                    transport: transport
                )
            }
        }
    }

    private func finishAfterPickupGeocode(
        pending: [(id: UUID, display: String, lines: [(String, Int)])],
        coordByAddress: [String: CLLocationCoordinate2D],
        destination: String,
        startRaw: String?,
        transport: RouteTransportPreference
    ) {
        var waypoints: [PickupWaypoint] = []
        for stop in pending {
            guard let coord = coordByAddress[stop.display] else {
                DispatchQueue.main.async {
                    self.presenter?.routePlanningFailed(message: "Не удалось найти координаты: \(stop.display)")
                }
                return
            }
            let lines = stop.lines.map { PickupLineItem(itemName: $0.0, quantity: $0.1) }
            waypoints.append(
                PickupWaypoint(
                    id: stop.id,
                    addressKey: stop.display.lowercased(),
                    displayAddress: stop.display,
                    coordinate: coord,
                    lines: lines
                )
            )
        }

        let orderedPickups = PickupRouteOrdering.orderPickups(waypoints)

        geocoder.geocodeAddress(destination) { [weak self] destResult in
            guard let self else { return }
            DispatchQueue.main.async {
                switch destResult {
                case .failure(let err):
                    self.presenter?.routePlanningFailed(message: self.message(for: err, context: "мероприятия"))
                case .success(let destCoord):
                    if let sr = startRaw, !sr.isEmpty {
                        self.geocoder.geocodeAddress(sr) { [weak self] startRes in
                            guard let self else { return }
                            DispatchQueue.main.async {
                                switch startRes {
                                case .failure(let err):
                                    self.presenter?.routePlanningFailed(
                                        message: self.message(for: err, context: "точки старта")
                                    )
                                case .success(let startCoord):
                                    self.assembleRoutePayload(
                                        startCoord: startCoord,
                                        startLabel: sr,
                                        orderedPickups: orderedPickups,
                                        destCoord: destCoord,
                                        destinationTitle: destination,
                                        transport: transport
                                    )
                                }
                            }
                        }
                    } else {
                        self.assembleRoutePayload(
                            startCoord: nil,
                            startLabel: nil,
                            orderedPickups: orderedPickups,
                            destCoord: destCoord,
                            destinationTitle: destination,
                            transport: transport
                        )
                    }
                }
            }
        }
    }

    private func assembleRoutePayload(
        startCoord: CLLocationCoordinate2D?,
        startLabel: String?,
        orderedPickups: [PickupWaypoint],
        destCoord: CLLocationCoordinate2D,
        destinationTitle: String,
        transport: RouteTransportPreference
    ) {
        var legsCoordinates: [CLLocationCoordinate2D] = []
        if let sc = startCoord {
            legsCoordinates.append(sc)
        }
        legsCoordinates.append(contentsOf: orderedPickups.map(\.coordinate))
        legsCoordinates.append(destCoord)

        guard legsCoordinates.count >= 2 else {
            presenter?.routePlanningFailed(message: "Недостаточно точек для маршрута.")
            return
        }

        let yandexURL = YandexMapsRouteURLBuilder.routeURL(
            coordinates: legsCoordinates,
            transport: transport
        )

        let startTuple: (coord: CLLocationCoordinate2D, label: String)? = {
            guard let sc = startCoord, let sl = startLabel, !sl.isEmpty else { return nil }
            return (sc, sl)
        }()

        routeAssembler.assemble(waypoints: legsCoordinates, transport: transport) { [weak self] asm in
            guard let self else { return }
            DispatchQueue.main.async {
                switch asm {
                case .failure(let error):
                    self.presenter?.routePlanningFailed(message: error.localizedDescription)
                case .success(let assembled):
                    let stops = self.makeStopPresentations(
                        start: startTuple,
                        pickups: orderedPickups,
                        destinationTitle: destinationTitle,
                        destinationCoord: destCoord
                    )
                    let summary = self.summaryText(legs: assembled.legs, usedRoadDirections: assembled.usedRoadDirections)
                    let model = RoutePlanningMapModel(
                        coordinates: assembled.coordinates,
                        stops: stops,
                        yandexURL: yandexURL,
                        transport: transport,
                        summary: summary
                    )
                    self.presenter?.routePlanningBuilt(model: model)
                }
            }
        }
    }

    private func geocodeSerial(
        addresses: [String],
        completion: @escaping (Result<[String: CLLocationCoordinate2D], RoutePlanningGeocodeFailure>) -> Void
    ) {
        var map: [String: CLLocationCoordinate2D] = [:]
        func step(_ index: Int) {
            if index == addresses.count {
                completion(.success(map))
                return
            }
            let addr = addresses[index]
            geocoder.geocodeAddress(addr) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(.message(self.message(for: error, context: "адреса"))))
                case .success(let coord):
                    map[addr] = coord
                    step(index + 1)
                }
            }
        }
        step(0)
    }

    private static func uniqueOrdered(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for a in addresses {
            if seen.insert(a).inserted {
                out.append(a)
            }
        }
        return out
    }

    private func message(for error: AddressGeocoderError, context: String) -> String {
        "\(context): \(GeocodingUserMessage.message(for: error))"
    }

    private func makeStopPresentations(
        start: (coord: CLLocationCoordinate2D, label: String)?,
        pickups: [PickupWaypoint],
        destinationTitle: String,
        destinationCoord: CLLocationCoordinate2D
    ) -> [RouteStopPresentation] {
        var out: [RouteStopPresentation] = []
        var idx = 1
        if let start {
            out.append(
                RouteStopPresentation(
                    id: UUID(),
                    index: idx,
                    title: "Старт",
                    subtitle: start.label,
                    coordinate: start.coord,
                    lines: []
                )
            )
            idx += 1
        }
        for p in pickups {
            let lines = p.lines.map { PickupLineDisplay(name: $0.itemName, quantity: $0.quantity) }
            out.append(
                RouteStopPresentation(
                    id: p.id,
                    index: idx,
                    title: "Забор",
                    subtitle: p.displayAddress,
                    coordinate: p.coordinate,
                    lines: lines
                )
            )
            idx += 1
        }
        out.append(
            RouteStopPresentation(
                id: UUID(),
                index: idx,
                title: "Мероприятие",
                subtitle: destinationTitle,
                coordinate: destinationCoord,
                lines: []
            )
        )
        return out
    }

    private func summaryText(legs: [MKRoute], usedRoadDirections: Bool) -> String? {
        if !usedRoadDirections {
            return "Маршрут по дорогам не найден; на карте — прямое соединение точек. Уточните адреса или откройте маршрут в Яндекс.Картах."
        }
        guard !legs.isEmpty else { return nil }
        let meters = legs.reduce(0.0) { $0 + $1.distance }
        let km = meters / 1000.0
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "ru_RU")
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 1
        let num = nf.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
        return "Ориентировочно \(num) км по выбранному типу маршрута"
    }
}

private enum RoutePlanningGeocodeFailure: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}
