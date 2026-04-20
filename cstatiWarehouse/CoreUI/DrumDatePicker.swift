//
// DrumDatePicker.swift
// cstatiWarehouse
//

import SwiftUI

/// Три колонки `Picker(.wheel)` + общий `appGlass`. Декор поверх колеса — только с
/// `allowsHitTesting(false)` (раньше `mask`/`overlay` без этого съедали скролл).
struct DrumDatePicker: View {

    @Binding var selection: Date

    @State private var day: Int
    @State private var month: Int
    @State private var year: Int

    private let years: [Int]
    private static let monthNames = Calendar.current.standaloneMonthSymbols

    init(selection: Binding<Date>) {
        _selection = selection
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: selection.wrappedValue)
        let d = comps.day   ?? 1
        let m = comps.month ?? 1
        let y = comps.year  ?? Calendar.current.component(.year, from: Date())
        _day   = State(initialValue: d)
        _month = State(initialValue: m)
        _year  = State(initialValue: y)

        let currentYear = Calendar.current.component(.year, from: Date())
        years = Array((currentYear - 5)...(currentYear + 20))
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

            HStack(spacing: 8) {
                wheelColumn(title: "День", width: 88) { dayColumn }
                wheelColumn(title: "Месяц", width: 118) { monthColumn }
                wheelColumn(title: "Год", width: 98) { yearColumn }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .foregroundStyle(.white.opacity(0.92))
        .colorScheme(.dark)
    }

    // MARK: Columns

    private var dayColumn: some View {
        Picker("", selection: $day) {
            ForEach(1...daysInSelectedMonth, id: \.self) { d in
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
            ForEach(1...12, id: \.self) { m in
                Text(monthLabel(m))
                    .font(font: .bold, size: 18)
                    .tag(m)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: month) {
            clampDay()
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
            clampDay()
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

    private func clampDay() {
        let maxDay = daysInSelectedMonth
        if day > maxDay { day = maxDay }
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
                .frame(width: width, height: 108)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 34)
                        .padding(.horizontal, 6)
                        .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.5), location: 0),
                            .init(color: .clear, location: 0.2),
                            .init(color: .clear, location: 0.8),
                            .init(color: .black.opacity(0.5), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
