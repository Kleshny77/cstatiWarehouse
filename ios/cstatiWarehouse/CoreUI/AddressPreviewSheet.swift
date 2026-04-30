//
//  AddressPreviewSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import MapKit
import SwiftUI

struct AddressPreviewSheet: View {

    let title: String
    let address: String
    let onClose: () -> Void

    private let geocoder = AddressGeocoder()

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var phase: Phase = .loading

    private enum Phase {
        case loading
        case located
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(address)
                            .font(font: .semiBold, size: 15)
                            .defaultTextStyle()
                            .fixedSize(horizontal: false, vertical: true)

                        Group {
                            switch phase {
                            case .loading:
                                ProgressView()
                                    .tint(Color.brandAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            case .failed(let message):
                                Text(message)
                                    .font(font: .semiBold, size: 14)
                                    .foregroundStyle(Color.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            case .located:
                                if let coordinate {
                                    Map(position: $mapPosition) {
                                        Annotation("Точка", coordinate: coordinate) {
                                            Circle()
                                                .fill(Color.brandAccent)
                                                .frame(width: 16, height: 16)
                                                .overlay {
                                                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 2)
                                                }
                                        }
                                    }
                                    .mapStyle(.standard(elevation: .flat))
                                    .frame(height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    }
                                }
                            }
                        }

                        Text("Если метка не совпадает с нужным местом — допишите город, индекс или ориентир в адресе.")
                            .font(font: .semiBold, size: 12)
                            .foregroundStyle(Color.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        onClose()
                    }
                    .font(font: .semiBold, size: 16)
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .onAppear {
            runLookup()
        }
    }

    private func runLookup() {
        phase = .loading
        coordinate = nil
        geocoder.geocodeAddress(address) { result in
            switch result {
            case .failure(let error):
                phase = .failed(GeocodingUserMessage.message(for: error))
            case .success(let coord):
                coordinate = coord
                phase = .located
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    )
                )
            }
        }
    }
}

struct AddressPreviewRouteContext: Identifiable {
    let title: String
    let address: String

    var id: String { "\(title)|\(address)" }
}
