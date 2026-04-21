//
// DrumDatePicker.swift
// cstatiWarehouse
//

import SwiftUI

/// Три колонки `Picker(.wheel)` внутри одного `appGlass`; без отдельных фонов/оверлеев на колонках,
/// чтобы не дублировать границы и «таблетку» поверх системного wheel.
struct DrumDatePicker: View {

    @Binding var selection: Date

    @State private var day: Int
    @State private var month: Int
    @State private var year: Int

    private let years: [Int]
    private static let monthNames = Calendar.current.standaloneMonthSymbols

    init(selection: Binding<Date>) {
        _selection = selection
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let boundDay = cal.startOfDay(for: selection.wrappedValue)
        let base = boundDay < startOfToday ? startOfToday : boundDay
        if base != boundDay {
            selection.wrappedValue = base
        }
        let comps = cal.dateComponents([.day, .month, .year], from: base)
        let d = comps.day   ?? 1
        let m = comps.month ?? 1
        let y = comps.year  ?? cal.component(.year, from: Date())
        _day   = State(initialValue: d)
        _month = State(initialValue: m)
        _year  = State(initialValue: y)

        let currentYear = cal.component(.year, from: Date())
        years = Array(currentYear...(currentYear + 20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(selectedDateLabel)
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 2)

            HStack(spacing: 10) {
                wheelColumn(title: "День", width: 80) { dayColumn }
                wheelColumn(title: "Месяц", width: 108) { monthColumn }
                wheelColumn(title: "Год", width: 92) { yearColumn }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .appGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .foregroundStyle(.white.opacity(0.92))
        .colorScheme(.dark)
    }

    // MARK: Columns

    private var dayColumn: some View {
        Picker("", selection: $day) {
            ForEach(minDayInSelectedMonth...daysInSelectedMonth, id: \.self) { d in
                Text(String(format: "%02d", d))
                    .font(font: .bold, size: 20)
                    .tag(d)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: day) { commit() }
    }

    private var monthColumn: some View {
        Picker("", selection: $month) {
            ForEach(minMonthInSelectedYear...12, id: \.self) { m in
                Text(monthLabel(m))
                    .font(font: .bold, size: 18)
                    .tag(m)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: month) {
            clampMonthAndDay()
            commit()
        }
    }

    private var yearColumn: some View {
        Picker("", selection: $year) {
            ForEach(years, id: \.self) { y in
                Text(String(y))
                    .font(font: .bold, size: 20)
                    .tag(y)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: year) {
            clampMonthAndDay()
            commit()
        }
    }

    // MARK: Helpers

    private var selectedDateLabel: String {
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = year
        guard let date = Calendar.current.date(from: comps) else { return "—" }
        return date.formatted(
            .dateTime
                .locale(Locale(identifier: "ru_RU"))
                .day(.twoDigits)
                .month(.wide)
                .year()
        )
    }

    private var daysInSelectedMonth: Int {
        var comps = DateComponents()
        comps.year  = year
        comps.month = month
        let date = Calendar.current.date(from: comps) ?? Date()
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    /// Год / месяц / день «сегодня» в текущем календаре (нижняя граница выбора).
    private var todayYMD: (y: Int, m: Int, d: Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    private var minMonthInSelectedYear: Int {
        let (ty, tm, _) = todayYMD
        return year > ty ? 1 : tm
    }

    private var minDayInSelectedMonth: Int {
        let (ty, tm, td) = todayYMD
        if year > ty { return 1 }
        if year < ty { return 1 }
        if month > tm { return 1 }
        if month < tm { return 1 }
        return td
    }

    private func clampMonthAndDay() {
        let minM = minMonthInSelectedYear
        if month < minM { month = minM }
        clampDay()
    }

    private func clampDay() {
        let maxDay = daysInSelectedMonth
        if day > maxDay { day = maxDay }
        let minD = minDayInSelectedMonth
        if day < minD { day = minD }
    }

    private func monthLabel(_ month: Int) -> String {
        String(Self.monthNames[month - 1].prefix(3)).capitalized
    }

    private func wheelColumn<Content: View>(title: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(font: .semiBold, size: 11)
                .foregroundStyle(.white.opacity(0.55))

            content()
                .frame(width: width, height: 120)
                .clipped()
        }
    }

    private func commit() {
        var comps = DateComponents()
        comps.day   = day
        comps.month = month
        comps.year  = year
        if let date = Calendar.current.date(from: comps) {
            selection = date
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        VStack {
            DrumDatePicker(selection: .constant(.now))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(20)
        }
    }
}
