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
                                eventCard(event)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        HStack {
            Text("Списания")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer()
            Button("Закрыть") {
                onDismiss()
            }
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .semiBold, size: 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
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
        return "id • " + event.archivedByUserID.uuidString.prefix(8).lowercased()
    }
}
