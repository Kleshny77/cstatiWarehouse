//
//  OverviewView.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Charts
import MapKit
import SwiftUI

struct OverviewView: View {

    @Bindable var presenter: OverviewPresenter

    init(presenter: OverviewPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()

            if let emptyMessage = presenter.emptyOrganizationMessage {
                emptyStateView(message: emptyMessage)
            } else if presenter.isLoading && presenter.metrics == nil {
                loadingView
            } else if let metrics = presenter.metrics {
                dashboardContent(metrics: metrics, snapshot: presenter.overviewSnapshot)
            } else if let errorMessage = presenter.errorMessage {
                errorView(message: errorMessage)
            }
        }
        .sheet(isPresented: $presenter.isRoutePlanningPresented) {
            RoutePlanningAssembly.assemble(onDismiss: {
                presenter.isRoutePlanningPresented = false
            })
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(
        metrics: DashboardMetrics,
        snapshot: OverviewAnalyticsSnapshot?
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView

                if let passive = presenter.passiveNoticeMessage {
                    PassiveNetworkBanner(
                        message: passive,
                        onRetry: {
                            Task { await presenter.refreshAsync() }
                        },
                        onDismiss: {
                            presenter.dismissPassiveNotice()
                        }
                    )
                }

                mapRouteTeaserCard()

                metricsCardsView(metrics: metrics)

                if let snapshot {
                    shelfRiskChartView(rows: snapshot.shelfRiskRows)
                }

                if !metrics.categoryDistribution.isEmpty {
                    categoryDistributionView(distribution: metrics.categoryDistribution)
                }

                if !metrics.stockTrend.isEmpty {
                    stockTrendChartView(trend: metrics.stockTrend)
                }

                if !metrics.expiringItems.isEmpty {
                    expiringItemsView(items: metrics.expiringItems)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .accessibilityIdentifier(AccessibilityID.Overview.root)
        }
        .refreshable {
            await presenter.refreshAsync()
        }
    }

    // MARK: - Map teaser

    private func mapRouteTeaserCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Маршрут по адресам")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Постройте оптимальный объезд точек хранения на карте.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))

            Map(initialPosition: .region(OverviewDashboardLayout.routeTeaserRegion)) { }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }

            Button {
                presenter.routePlanningTapped()
            } label: {
                Text("Планирование маршрута")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "8A80FF").opacity(0.55))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Overview.routePlanningButton)
        }
        .padding(16)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Обзор")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            if !presenter.organizationTitle.isEmpty {
                Text(presenter.organizationTitle)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Metrics Cards

    @ViewBuilder
    private func metricsCardsView(metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ключевые показатели")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    metricCard(
                        title: "Всего позиций",
                        value: "\(metrics.totalItems)",
                        icon: "cube.box.fill",
                        color: .blue
                    )

                    metricCard(
                        title: "В наличии",
                        value: "\(metrics.inStockItems)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    metricCard(
                        title: "Истекает скоро",
                        value: "\(metrics.expiringSoon)",
                        icon: "clock.fill",
                        color: metrics.expiringSoon > 0 ? .orange : .gray
                    )

                    metricCard(
                        title: "Категорий",
                        value: "\(metrics.categoriesCount)",
                        icon: "folder.fill",
                        color: .purple
                    )
                }
                .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 160, height: 140)
    }

    // MARK: - Shelf risk (локально по позициям)

    @ViewBuilder
    private func shelfRiskChartView(rows: [OverviewShelfRiskRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Риски по срокам")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Строк", row.lineCount),
                        y: .value("Группа", row.band.chartAxisLabel)
                    )
                    .foregroundStyle(OverviewDashboardLayout.shelfGradient(for: row.band))
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(rows.count) * 40 + 40)
            }
            .padding(16)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Stock Trend Chart

    @ViewBuilder
    private func stockTrendChartView(trend: [StockDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Динамика запасов")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                Chart(trend) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Количество", point.quantity)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    AreaMark(
                        x: .value("Дата", point.date),
                        y: .value("Количество", point.quantity)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .cyan.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month(.abbreviated))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.white.opacity(0.1))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                    }
                }
                .frame(height: 200)
            }
            .padding(16)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Category Distribution (данные API — сохранённый стиль графика)

    @ViewBuilder
    private func categoryDistributionView(distribution: [CategoryDistribution]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Распределение по категориям")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                Chart(distribution.prefix(8)) { item in
                    BarMark(
                        x: .value("Количество", item.count),
                        y: .value("Категория", item.categoryName)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let category = value.as(String.self) {
                                Text(category)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(min(distribution.count, 8)) * 40 + 40)
            }
            .padding(16)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Expiring Items

    @ViewBuilder
    private func expiringItemsView(items: [ExpiringItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Истекающие позиции")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(items.prefix(5)) { item in
                    expiringItemRow(item: item)

                    if item.id != items.prefix(5).last?.id {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .padding(16)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func expiringItemRow(item: ExpiringItem) -> some View {
        Button {
            presenter.expiringItemTapped(item)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(urgencyColor(for: item.daysUntil))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(urgencyText(for: item.daysUntil))
                        .font(.system(size: 13))
                        .foregroundStyle(urgencyColor(for: item.daysUntil))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.quantity) шт")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(item.expirationDate, format: .dateTime.day().month(.abbreviated))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func urgencyColor(for daysUntil: Int) -> Color {
        if daysUntil < 0 {
            return .red
        } else if daysUntil == 0 {
            return .red
        } else if daysUntil <= 1 {
            return .orange
        } else if daysUntil <= 3 {
            return .yellow
        } else {
            return .green
        }
    }

    private func urgencyText(for daysUntil: Int) -> String {
        if daysUntil < 0 {
            return "Просрочено"
        } else if daysUntil == 0 {
            return "Истекает сегодня"
        } else if daysUntil == 1 {
            return "Истекает завтра"
        } else {
            return "Истекает через \(daysUntil) дн."
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))

            Text(message)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)

            Text("Загрузка аналитики...")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Ошибка загрузки")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await presenter.refreshAsync() }
            } label: {
                Text("Повторить")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }
}

// MARK: - OverviewDashboardLayout

private enum OverviewDashboardLayout {
    static let routeTeaserRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    static func shelfGradient(for band: ShelfRiskBand) -> LinearGradient {
        switch band {
        case .expired:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case .withinWeek:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .withinMonth:
            return LinearGradient(colors: [.yellow.opacity(0.95), .green.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
        case .safeOrNoShelf:
            return LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }
}
