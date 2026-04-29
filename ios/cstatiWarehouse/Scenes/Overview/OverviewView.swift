//
//  OverviewView.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Charts
import SwiftUI

struct OverviewView: View {

    @Bindable var presenter: OverviewPresenter

    init(presenter: OverviewPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
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
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .refreshable {
                await presenter.refreshAsync()
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
        .sheet(isPresented: $presenter.isRoutePlanningPresented) {
            RoutePlanningAssembly.assemble(onDismiss: {
                presenter.isRoutePlanningPresented = false
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Обзор")
                .font(font: .bold, size: 28)
                .defaultTextStyle()
            Text("Запасы по категориям и зоны риска по сроку годности")
                .font(font: .semiBold, size: 15)
                .secondaryTextStyle()
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var content: some View {
        if let emptyMessage = presenter.emptyOrganizationMessage {
            Text(emptyMessage)
                .font(font: .semiBold, size: 15)
                .secondaryTextStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if presenter.isLoading && presenter.snapshot == nil {
            overviewSkeleton
        } else if let snapshot = presenter.snapshot {
            analyticsSection(snapshot)
            mapsPlaceholderSection
            extraPlaceholderSection
        } else if !presenter.isLoading {
            Text("Нет данных")
                .font(font: .semiBold, size: 15)
                .secondaryTextStyle()
        }
    }

    private var overviewSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .frame(height: 24)
                .frame(maxWidth: 200)
            overviewSkeletonGlass(height: 220)
            overviewSkeletonGlass(height: 200)
        }
        .shimmering()
    }

    private func overviewSkeletonGlass(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(height: 18)
                .frame(maxWidth: 160)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .frame(height: height)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func analyticsSection(_ snapshot: OverviewAnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(snapshot.organizationTitle)
                .font(font: .bold, size: 18)
                .defaultTextStyle()

            glassCard(
                title: "Запасы по категориям",
                subtitle: "Сумма единиц по корневым позициям. Нажмите строку — откроется склад с фильтром по категории."
            ) {
                if snapshot.categoryRows.isEmpty {
                    Text("Нет позиций на складе")
                        .font(font: .semiBold, size: 14)
                        .secondaryTextStyle()
                } else {
                    Chart(snapshot.categoryRows) { row in
                        BarMark(
                            x: .value("Единиц", row.totalUnits),
                            y: .value("Категория", row.title)
                        )
                        .foregroundStyle(Color.brandAccent)
                    }
                    .chartPlotStyle { plot in
                        plot.padding(.trailing, 8)
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(font: .semiBold, size: 11)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let title = value.as(String.self) {
                                    Text(title)
                                        .font(font: .semiBold, size: 11)
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(max(200, snapshot.categoryRows.count * 32)))

                    VStack(spacing: 8) {
                        ForEach(snapshot.categoryRows) { row in
                            categoryDetailRow(row)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            glassCard(
                title: "Срок годности",
                subtitle: "Сколько складских строк (позиций/вариантов) в каждой зоне внимания."
            ) {
                if snapshot.categoryRows.isEmpty {
                    Text("Нет позиций на складе")
                        .font(font: .semiBold, size: 14)
                        .secondaryTextStyle()
                } else {
                    Chart(snapshot.shelfRiskRows) { row in
                        BarMark(
                            x: .value("Зона", row.band.chartAxisLabel),
                            y: .value("Строк", row.lineCount)
                        )
                        .foregroundStyle(shelfRiskColor(row.band))
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let str = value.as(String.self) {
                                    Text(str)
                                        .font(font: .semiBold, size: 10)
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(font: .semiBold, size: 11)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(height: 240)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.shelfRiskRows) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle()
                                    .fill(shelfRiskColor(row.band))
                                    .frame(width: 8, height: 8)
                                Text(row.band.title)
                                    .font(font: .semiBold, size: 12)
                                    .secondaryTextStyle()
                                Spacer(minLength: 0)
                                Text("\(row.lineCount)")
                                    .font(font: .semiBold, size: 12)
                                    .defaultTextStyle()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func categoryDetailRow(_ row: OverviewCategoryRow) -> some View {
        Button {
            presenter.categoryRowTapped(row)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(font: .semiBold, size: 15)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(formattedUnits(row.totalUnits))
                        .font(font: .semiBold, size: 12)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 8)
                if row.canNavigateToWarehouse {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandAccent)
                } else {
                    Text("сводно")
                        .font(font: .semiBold, size: 11)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(row.canNavigateToWarehouse ? 1 : 0.65)
        }
        .buttonStyle(.pressable)
        .disabled(!row.canNavigateToWarehouse)
    }

    private func formattedUnits(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "ru_RU")
        nf.numberStyle = .decimal
        let num = nf.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(num) ед."
    }

    private func shelfRiskColor(_ band: ShelfRiskBand) -> Color {
        switch band {
        case .expired:
            return Color.error
        case .withinWeek:
            return Color.warning
        case .withinMonth:
            return Color.brandAccent
        case .safeOrNoShelf:
            return Color.success.opacity(0.9)
        }
    }

    private var mapsPlaceholderSection: some View {
        Button {
            presenter.routePlanningTapped()
        } label: {
            glassCard(title: "Маршруты и карта", subtitle: "Оптимальный порядок забора и маршрут на карте") {
                HStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.brandAccent)
                        .frame(width: 44, height: 44)
                        .appGlass(in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Спланировать вывоз")
                            .font(font: .semiBold, size: 15)
                            .defaultTextStyle()
                        Text("Выберите позиции, адрес мероприятия и постройте маршрут с открытием в Яндекс.Картах.")
                            .font(font: .semiBold, size: 13)
                            .secondaryTextStyle()
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandAccent)
                }
            }
        }
        .buttonStyle(.pressable)
    }

    private var extraPlaceholderSection: some View {
        glassCard(title: "Ещё инструменты", subtitle: "Дополнительные сервисы появятся здесь") {
            HStack(spacing: 12) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .appGlass(in: Circle())
                Text("Резервируем место под отчёты, экспорт и интеграции.")
                    .font(font: .semiBold, size: 13)
                    .secondaryTextStyle()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    private func glassCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(font: .bold, size: 17)
                    .defaultTextStyle()
                Text(subtitle)
                    .font(font: .semiBold, size: 13)
                    .secondaryTextStyle()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    OverviewAssembly.assemble(presenter: OverviewAssembly.makePresenter(tabCoordinator: MainTabCoordinator()))
}
