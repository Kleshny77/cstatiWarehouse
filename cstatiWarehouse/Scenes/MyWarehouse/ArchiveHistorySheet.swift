//
//  ArchiveHistorySheet.swift
//  cstatiWarehouse
//

import SwiftUI

/// Список операций списания: позиция, причина, комментарий, кто и когда.
struct ArchiveHistorySheet: View {
    let events: [ArchiveEvent]
    let isLoading: Bool
    let onDismiss: () -> Void

    private static let dateTime: Date.FormatStyle = .dateTime
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .year()
        .hour()
        .minute()

    @State private var selectedEvent: ArchiveEvent? = nil

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(alignment: .leading, spacing: 0) {
                header
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if events.isEmpty {
                    Spacer()
                    Text("Пока нет списаний")
                        .font(font: .semiBold, size: 15)
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(events) { event in
                                Button {
                                    AppHaptics.selection()
                                    selectedEvent = event
                                } label: {
                                    eventCard(event)
                                }
                                .buttonStyle(.plain)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            ArchiveEventDetailSheet(event: event, onDismiss: { selectedEvent = nil })
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Списания")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer(minLength: 12)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private func eventCard(_ event: ArchiveEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.itemName)
                    .font(font: .bold, size: 16)
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("−\(event.quantity) шт.")
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(event.reason.title)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(.white.opacity(0.88))

            let detail = event.reasonDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                Text(detail)
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Label {
                    Text(actorLabel(event))
                        .font(font: .semiBold, size: 12)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 8)

                Text(event.archivedAt.formatted(Self.dateTime))
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func actorLabel(_ event: ArchiveEvent) -> String {
        let s = event.archivedByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return "участник"
    }
}

// MARK: - ArchiveEventDetailSheet

struct ArchiveEventDetailSheet: View {
    let event: ArchiveEvent
    let onDismiss: () -> Void

    private static let dateTime: Date.FormatStyle = .dateTime
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .year()
        .hour()
        .minute()

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        detailsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .presentationDetents([.height(420), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.itemName)
                    .font(font: .bold, size: 22)
                    .defaultTextStyle()
                    .lineLimit(2)
                Text("списание · \(event.archivedAt.formatted(Self.dateTime))")
                    .font(font: .semiBold, size: 13)
                    .secondaryTextStyle()
            }
            Spacer(minLength: 12)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(icon: "archivebox", label: "Количество", value: "\(event.quantity) шт.")
            divider
            row(icon: "tag", label: "Причина", value: event.reason.title)
            if !event.reasonDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                divider
                row(icon: "text.alignleft", label: "Комментарий",
                    value: event.reasonDetail.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            divider
            row(icon: "person.fill", label: "Кто списал", value: actorName)
        }
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 20)
            Text(label)
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.65))
                .frame(minWidth: 90, alignment: .leading)
            Spacer()
            Text(value)
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var actorName: String {
        let s = event.archivedByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "участник" : s
    }
}
