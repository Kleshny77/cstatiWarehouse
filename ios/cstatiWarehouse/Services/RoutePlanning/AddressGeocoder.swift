//
//  AddressGeocoder.swift
//  cstatiWarehouse
//
//  Created by Артём on 09.02.2026.
//

import CoreLocation
import Foundation
import MapKit

enum AddressGeocoderError: Error {
    case emptyQuery
    case notFound
    case underlying(Error)
}

protocol AddressGeocoderProtocol: AnyObject {
    func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, AddressGeocoderError>) -> Void)
}

final class AddressGeocoder: AddressGeocoderProtocol {

    func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, AddressGeocoderError>) -> Void) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(.emptyQuery))
            }
            return
        }

        guard let request = MKGeocodingRequest(addressString: trimmed) else {
            DispatchQueue.main.async {
                completion(.failure(.notFound))
            }
            return
        }

        Task {
            do {
                let items = try await request.mapItems
                await MainActor.run {
                    guard let first = items.first else {
                        completion(.failure(.notFound))
                        return
                    }
                    completion(.success(first.location.coordinate))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.underlying(error)))
                }
            }
        }
    }
}
