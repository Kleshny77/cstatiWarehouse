//
//  PickupRouteOrdering.swift
//  cstatiWarehouse
//
//  Created by Артём on 09.02.2026.
//

import CoreLocation
import MapKit

struct PickupWaypoint: Identifiable {
    let id: UUID
    let addressKey: String
    let displayAddress: String
    let coordinate: CLLocationCoordinate2D
    var lines: [PickupLineItem]
}

struct PickupLineItem: Equatable {
    let itemName: String
    let quantity: Int
}

enum PickupRouteOrdering {

    static func orderPickups(_ pickups: [PickupWaypoint]) -> [PickupWaypoint] {
        guard pickups.count > 1 else { return pickups }

        var remaining = pickups.sorted { lhs, rhs in
            if lhs.displayAddress != rhs.displayAddress {
                return lhs.displayAddress.localizedCompare(rhs.displayAddress) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var ordered: [PickupWaypoint] = []
        var current = remaining.removeFirst()
        ordered.append(current)

        while !remaining.isEmpty {
            guard let bestIdx = remaining.indices.min(by: {
                distanceMeters(current.coordinate, remaining[$0].coordinate)
                    < distanceMeters(current.coordinate, remaining[$1].coordinate)
            }) else {
                break
            }
            current = remaining.remove(at: bestIdx)
            ordered.append(current)
        }

        return ordered
    }

    private static func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        MKMapPoint(a).distance(to: MKMapPoint(b))
    }
}
