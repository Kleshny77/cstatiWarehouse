//
//  ItemDetailSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

/// Карточка деталей конкретной позиции (лист или вариант в группе). Корни-группы не открываются здесь —
/// они раскрываются inline на главном экране склада.
struct ItemDetailSheet: View {
    let item: Item
    /// Имя родительской группы для подпозиций.
    let parentName: String?
    /// Имя участника по `heldByUserID`, если удалось сопоставить со списком организации.
    let holderDisplayName: String?
    let onEdit: () -> Void
    let onArchive: (() -> Void)?
    let onDismiss: () -> Void

    init(
        item: Item,
        parentName: String? = nil,
        holderDisplayName: String? = nil,
        onEdit: @escaping () -> Void,
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

    private static let dateFormat = Date.FormatStyle()
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .year()

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
                        if item.imageURL != nil {
                            imageSection
                        }
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
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var imageSection: some View {
        RemoteImageView(url: item.imageURL) {
            EmptyView()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

            if let location = item.locationAddress, !location.isEmpty {
                divider
                detailRow(icon: "mappin.and.ellipse", label: "Местонахождение", value: location)
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
        switch line.measureUnit {
        case .liter:
            let vol = line.volumePerUnit.map { formatLiters($0) } ?? "—"
            return "\(line.quantity) упак. × \(vol)"
        case .piece:
            return "\(line.quantity) шт."
        case .package:
            return "\(line.quantity) упак."
        case .meter:
            return "\(line.quantity) м"
        }
    }

    private func formatLiters(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let num = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return "\(num) л"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
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

    private func expirationRow(_ status: ExpirationStatus) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 20)
            Text("Срок годности")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(status.title)
                .font(font: .semiBold, size: 14)
                .foregroundStyle(status.badgeColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
