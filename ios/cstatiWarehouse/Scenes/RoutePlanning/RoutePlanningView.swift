//
//  RoutePlanningView.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import MapKit
import SwiftUI

struct RoutePlanningView: View {

    @Bindable var presenter: RoutePlanningPresenter
    @Environment(\.openURL) private var openURL

    @State private var mapPosition: MapCameraPosition = .automatic

    init(presenter: RoutePlanningPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCopy
                        transportPicker
                        addressFields
                        itemsSection
                        buildButton
                        mapSection
                        stopsSection
                        yandexLinkSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .overlay {
                    if presenter.isLoadingItems && presenter.rows.isEmpty {
                        ProgressView()
                            .tint(Color.brandAccent)
                            .scaleEffect(1.2)
                    }
                }
            }
            .navigationTitle("Маршруты и карта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        presenter.dismissTapped()
                    }
                    .font(font: .semiBold, size: 16)
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.errorMessage = nil } }
        )) {
            Button("OK") { presenter.errorMessage = nil }
        } message: {
            if let message = presenter.errorMessage {
                Text(message)
            }
        }
        .onChange(of: presenter.builtModel?.coordinates.count) { _, _ in
            syncMapRegion()
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Соберите забронированные позиции и постройте порядок остановок.")
                .font(font: .semiBold, size: 14)
                .secondaryTextStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var transportPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Тип маршрута")
                .font(font: .semiBold, size: 13)
                .foregroundStyle(Color.textSecondary)
            Picker("Транспорт", selection: $presenter.transport) {
                ForEach(RouteTransportPreference.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var addressFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassTextField(
                title: "Адрес мероприятия",
                placeholder: "Например, Москва, ул. …",
                text: $presenter.destinationAddress,
                keyboardType: .default,
                useFullWidth: true,
                autocapitalization: .words
            )
            AddressGeocodeInlinePreview(
                status: presenter.destinationGeocodePreviewStatus,
                manualCheckHint: "Адрес проверяется автоматически — без успешной проверки маршрут не построить.",
                secondaryLabelColor: Color.textSecondary,
                tertiaryLabelColor: Color.textTertiary
            )
            .onChange(of: presenter.destinationAddress) { _, _ in
                presenter.destinationAddressChanged()
            }

            GlassTextField(
                title: "Старт (необязательно)",
                placeholder: "Откуда выезжаете",
                text: $presenter.startAddress,
                keyboardType: .default,
                useFullWidth: true,
                autocapitalization: .words
            )
            AddressGeocodeInlinePreview(
                status: presenter.startGeocodePreviewStatus,
                manualCheckHint: "Если указали старт — он тоже проверится на карте.",
                secondaryLabelColor: Color.textSecondary,
                tertiaryLabelColor: Color.textTertiary
            )
            .onChange(of: presenter.startAddress) { _, _ in
                presenter.startAddressChanged()
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Что везём")
                .font(font: .bold, size: 17)
                .defaultTextStyle()

            if presenter.rows.isEmpty, !presenter.isLoadingItems {
                Text("Нет активных позиций для выбора.")
                    .font(font: .semiBold, size: 14)
                    .secondaryTextStyle()
            }

            ForEach(presenter.rows) { row in
                itemRow(row)
            }
        }
    }

    private func itemRow(_ row: RoutePlanningItemRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.name)
                        .font(font: .semiBold, size: 15)
                        .defaultTextStyle()
                    Text(row.categoryName)
                        .font(font: .semiBold, size: 12)
                        .secondaryTextStyle()
                    Text(row.locationAddress)
                        .font(font: .semiBold, size: 11)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text("\(presenter.selection[row.id] ?? 0) / \(row.maxQuantity)")
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(Color.textSecondary)
            }

            Stepper(
                value: quantityBinding(for: row),
                in: 0...row.maxQuantity
            ) {
                Text("Количество")
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func quantityBinding(for row: RoutePlanningItemRow) -> Binding<Int> {
        Binding(
            get: { presenter.selection[row.id] ?? 0 },
            set: { presenter.setQuantity(itemID: row.id, value: $0) }
        )
    }

    private var buildButton: some View {
        Button {
            presenter.buildRouteTapped()
        } label: {
            HStack {
                if presenter.isBuildingRoute {
                    ProgressView()
                        .tint(.white)
                }
                Text("Построить маршрут")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .semiBold, size: 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .buttonStyle(.pressable)
        .disabled(presenter.isBuildingRoute || presenter.isLoadingItems)
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Карта")
                .font(font: .bold, size: 17)
                .defaultTextStyle()

            if let model = presenter.builtModel, model.coordinates.count >= 2 {
                Map(position: $mapPosition) {
                    MapPolyline(coordinates: model.coordinates)
                        .stroke(Color.brandAccent, style: StrokeStyle(lineWidth: 4, lineJoin: .round))

                    ForEach(model.stops) { stop in
                        Annotation(stop.title, coordinate: stop.coordinate) {
                            stopPin(for: stop)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

                if let summary = model.summary {
                    Text(summary)
                        .font(font: .semiBold, size: 13)
                        .secondaryTextStyle()
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Text("Маршрут появится после расчёта.")
                        .font(font: .semiBold, size: 14)
                        .secondaryTextStyle()
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(height: 200)
                .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func stopPin(for stop: RouteStopPresentation) -> some View {
        VStack(spacing: 4) {
            Text("\(stop.index)")
                .font(font: .extraBold, size: 11)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.brandAccent))
                .overlay {
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Порядок остановок")
                .font(font: .bold, size: 17)
                .defaultTextStyle()

            if let stops = presenter.builtModel?.stops, !stops.isEmpty {
                ForEach(stops) { stop in
                    stopCard(stop)
                }
            } else {
                Text("Здесь будет список точек и количества по каждой остановке.")
                    .font(font: .semiBold, size: 14)
                    .secondaryTextStyle()
            }
        }
    }

    private func stopCard(_ stop: RouteStopPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(stop.index)")
                    .font(font: .extraBold, size: 13)
                    .foregroundStyle(Color.brandAccent)
                    .frame(width: 22, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.title)
                        .font(font: .semiBold, size: 15)
                        .defaultTextStyle()
                    Text(stop.subtitle)
                        .font(font: .semiBold, size: 13)
                        .secondaryTextStyle()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !stop.lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stop.lines, id: \.self) { line in
                        Text("• \(line.name) — \(line.quantity) шт.")
                            .font(font: .semiBold, size: 13)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var yandexLinkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = presenter.builtModel?.yandexURL {
                Button {
                    openURL(url)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Открыть этот маршрут в Яндекс.Картах")
                            .font(font: .semiBold, size: 15)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .buttonStyle(.pressable)

                Text("Ссылка учитывает выбранный тип маршрута (авто или транспорт).")
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private func syncMapRegion() {
        guard let coords = presenter.builtModel?.coordinates, coords.count >= 2 else { return }
        mapPosition = .region(Self.regionFitting(coords))
    }

    private static func regionFitting(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion()
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in coordinates.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = max((maxLat - minLat) * 1.5, 0.03)
        let lonDelta = max((maxLon - minLon) * 1.5, 0.03)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        return MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    RoutePlanningAssembly.assemble(onDismiss: {})
}
