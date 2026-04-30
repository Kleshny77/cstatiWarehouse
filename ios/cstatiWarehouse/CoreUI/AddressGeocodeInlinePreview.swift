//
//  AddressGeocodeInlinePreview.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import MapKit
import SwiftUI

enum AddressGeocodeInlineStatus: Equatable {
    case hidden
    case idleTyping
    case checking
    case ok(latitude: Double, longitude: Double)
    case failed(String)
}

struct AddressGeocodeInlinePreview: View {

    let status: AddressGeocodeInlineStatus
    let manualCheckHint: String
    let secondaryLabelColor: Color
    let tertiaryLabelColor: Color

    init(
        status: AddressGeocodeInlineStatus,
        manualCheckHint: String,
        secondaryLabelColor: Color = Color.textSecondary,
        tertiaryLabelColor: Color = Color.textTertiary
    ) {
        self.status = status
        self.manualCheckHint = manualCheckHint
        self.secondaryLabelColor = secondaryLabelColor
        self.tertiaryLabelColor = tertiaryLabelColor
    }

    private static let mapHeight: CGFloat = 200

    var body: some View {
        switch status {
        case .hidden:
            EmptyView()
        case .idleTyping:
            Text(manualCheckHint)
                .font(font: .semiBold, size: 12)
                .foregroundStyle(tertiaryLabelColor.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        case .checking:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color.brandAccent)
                Text("Ищем адрес на карте…")
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(secondaryLabelColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        case .ok(let lat, let lon):
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandAccent)
                    Text("Адрес найден — метка на карте совпадает с тем, что нашёл сервис.")
                        .font(font: .semiBold, size: 13)
                        .foregroundStyle(secondaryLabelColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Map(initialPosition: .region(Self.region(for: coord))) {
                    Annotation("Точка", coordinate: coord) {
                        Circle()
                            .fill(Color.brandAccent)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.65), lineWidth: 2)
                            }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: Self.mapHeight)
                .id("\(lat)-\(lon)")
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            }
        case .failed(let message):
            Text(message)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(Color.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func region(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    }
}
