//
//  RoutePlanningModels.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation

struct RoutePlanningItemRow: Identifiable, Hashable {
    let id: UUID
    let name: String
    let categoryName: String
    let maxQuantity: Int
    let locationAddress: String
}

struct RouteStopPresentation: Identifiable {
    let id: UUID
    let index: Int
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let lines: [PickupLineDisplay]
}

struct PickupLineDisplay: Hashable {
    let name: String
    let quantity: Int
}

struct RoutePlanningMapModel {
    let coordinates: [CLLocationCoordinate2D]
    let stops: [RouteStopPresentation]
    let yandexURL: URL?
    let transport: RouteTransportPreference
    let summary: String?
}
