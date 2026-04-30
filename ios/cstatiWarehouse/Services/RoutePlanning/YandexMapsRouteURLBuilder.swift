//
//  YandexMapsRouteURLBuilder.swift
//  cstatiWarehouse
//
//  Created by Артём on 09.02.2026.
//

import CoreLocation
import Foundation

enum YandexMapsRouteURLBuilder {

    static func routeURL(coordinates: [CLLocationCoordinate2D], transport: RouteTransportPreference) -> URL? {
        guard coordinates.count >= 2 else { return nil }

        let parts = coordinates.map { String(format: "%.6f,%.6f", $0.latitude, $0.longitude) }
        let rtext = parts.joined(separator: "~")

        var components = URLComponents(string: "https://yandex.ru/maps/")
        components?.queryItems = [
            URLQueryItem(name: "rtext", value: rtext),
            URLQueryItem(name: "rtt", value: transport.yandexRtt)
        ]
        return components?.url
    }
}
