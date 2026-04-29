//
//  RouteTransportPreference.swift
//  cstatiWarehouse
//
//  Created by Артём on 09.02.2026.
//

import MapKit

enum RouteTransportPreference: String, CaseIterable, Identifiable {
    case automobile
    case transit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automobile:
            return "На машине"
        case .transit:
            return "Общественный транспорт"
        }
    }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile:
            return .automobile
        case .transit:
            return .transit
        }
    }

    /// Параметр `rtt` для ссылок Яндекс.Карт.
    var yandexRtt: String {
        switch self {
        case .automobile:
            return "auto"
        case .transit:
            return "mt"
        }
    }
}
