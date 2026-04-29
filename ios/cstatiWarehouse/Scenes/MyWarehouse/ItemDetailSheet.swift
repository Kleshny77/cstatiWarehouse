//
//  ItemDetailSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

struct ItemDetailSheet: View {
    let item: Item
    let parentName: String?
    let holderDisplayName: String?
    let onEdit: (() -> Void)?
    let onArchive: (() -> Void)?
    let onDismiss: () -> Void

    init(
        item: Item,
        parentName: String? = nil,
        holderDisplayName: String? = nil,
        onEdit: (() -> Void)? = nil,
        onArchive: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.parentName = parentName
        self.holderDisplayName = holderDisplayName
        self.onEdit = onEdit
        self.onArchive = onArchive
        self.onDismiss = onDismiss
    }

    private static let dateTimeFormat = Date.FormatStyle()
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .year()
        .hour(.defaultDigits(amPM: .omitted))
        .minute(.twoDigits)

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        imageSection
                        detailsCard
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(font: .bold, size: 22)
                        .defaultTextStyle()
                        .lineLimit(2)
                    if let parentName, !item.variantLabel.isEmpty {
                        Text("Вариант · \(parentName)")
                            .font(font: .semiBold, size: 13)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .appGlass(in: Circle())
                    }
                    .buttonStyle(.pressable)
                }
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var displayTitle: String {
        if !item.variantLabel.isEmpty {
            return "\(item.name) · \(item.variantLabel)"
        }
        return item.name
    }

    private var hasImageURL: Bool {
        guard let url = item.imageURL else { return false }
        let raw = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        return !raw.isEmpty
    }

    @ViewBuilder
    private var imageSection: some View {
        if hasImageURL, let url = item.imageURL {
            RemoteImageView(url: url) {
                EmptyView()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description = item.description, !description.isEmpty {
                detailRow(icon: "text.alignleft", label: "Описание", value: description)
                divider
            }
            detailRow(icon: "tag", label: "Категория", value: item.categoryName)
            divider
            detailRow(icon: "shippingbox", label: "Количество", value: quantityDetailText(for: item))

            let expStatus = item.expirationStatus()
            if expStatus != .noShelfLife {
                divider
                expirationRow(expStatus)
            }

            if !item.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                divider
                detailRow(icon: "mappin.and.ellipse", label: "Местонахождение", value: item.locationAddress)
            }

            if let holderDisplayName {
                divider
                detailRow(icon: "person.fill", label: "Держит", value: holderDisplayName)
            }

            if case let .archived(reason, archivedAt) = item.status {
                divider
                detailRow(icon: reason.icon, label: "Списано", value: reason.title)
                divider
                detailRow(icon: "calendar", label: "Когда списано", value: archivedAt.formatted(Self.dateTimeFormat))
            }

            divider
            detailRow(icon: "clock", label: "Добавлено", value: item.createdAt.formatted(Self.dateTimeFormat))
        }
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let onArchive {
            Button {
                onArchive()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox")
                    Text("Списать со склада")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.85))
                )
            }
            .buttonStyle(.pressable)
        }
    }

    private func quantityDetailText(for line: Item) -> String {
        line.stockAccountingSummary
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func expirationRow(_ status: ExpirationStatus) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 8) {
                Text("Срок годности")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.65))
                Text(status.title)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(status.badgeColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
