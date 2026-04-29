//
//  MultiLegDrivingRouteAssembler.swift
//  cstatiWarehouse
//
//  Created by Артём on 09.02.2026.
//

import CoreLocation
import Foundation
import MapKit

struct AssembledRoute {
    let coordinates: [CLLocationCoordinate2D]
    let legs: [MKRoute]
    /// Ложь, если между точками нарисована только прямая (дорожный маршрут недоступен).
    let usedRoadDirections: Bool
}

enum MultiLegRouteError: LocalizedError {
    case emptyWaypoints
    case directionsFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyWaypoints:
            return "Недостаточно точек маршрута."
        case .directionsFailed(let message):
            return message
        }
    }
}

final class MultiLegDrivingRouteAssembler {

    func assemble(
        waypoints: [CLLocationCoordinate2D],
        transport: RouteTransportPreference,
        completion: @escaping (Result<AssembledRoute, MultiLegRouteError>) -> Void
    ) {
        guard waypoints.count >= 2 else {
            DispatchQueue.main.async {
                completion(.failure(.emptyWaypoints))
            }
            return
        }

        var allCoordinates: [CLLocationCoordinate2D] = []
        var legs: [MKRoute] = []
        let group = DispatchGroup()
        var directionsFailed = false

        for idx in 0..<(waypoints.count - 1) {
            group.enter()
            let request = MKDirections.Request()
            request.source = Self.mapItem(at: waypoints[idx])
            request.destination = Self.mapItem(at: waypoints[idx + 1])
            request.transportType = transport.mkTransportType

            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                DispatchQueue.main.async {
                    defer { group.leave() }
                    if error != nil {
                        directionsFailed = true
                        return
                    }
                    guard let route = response?.routes.first else {
                        directionsFailed = true
                        return
                    }
                    legs.append(route)
                    let segmentCoords = coordinates(from: route.polyline)
                    if idx == 0 {
                        allCoordinates.append(contentsOf: segmentCoords)
                    } else if !segmentCoords.isEmpty {
                        allCoordinates.append(contentsOf: segmentCoords.dropFirst())
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let roadsOk = !directionsFailed && !allCoordinates.isEmpty
            if roadsOk {
                completion(.success(AssembledRoute(coordinates: allCoordinates, legs: legs, usedRoadDirections: true)))
                return
            }
            if let fallback = self.fallbackLineString(waypoints: waypoints) {
                completion(.success(AssembledRoute(coordinates: fallback, legs: [], usedRoadDirections: false)))
                return
            }
            completion(.failure(.emptyWaypoints))
        }
    }

    private static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return MKMapItem(location: location, address: nil)
    }

    /// Прямая линия между точками, если MKDirections не вернул полилинию.
    private func fallbackLineString(waypoints: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D]? {
        guard waypoints.count >= 2 else { return nil }
        return waypoints
    }
}

private func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
    polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
    return coords.filter { CLLocationCoordinate2DIsValid($0) }
}
