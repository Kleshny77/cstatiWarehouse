//
// ItemDetailSheet.swift
// cstatiWarehouse
//

import SwiftUI

struct ItemDetailSheet: View {
    let item: Item
    let onEdit: () -> Void
    let onDismiss: () -> Void

    private static let dateFormat = Date.FormatStyle()
        .locale(Locale(identifier: "ru_RU"))
        .day(.twoDigits)
        .month(.abbreviated)
        .year()

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
        HStack(alignment: .top) {
            Text(item.name)
                .font(font: .bold, size: 22)
                .defaultTextStyle()
                .lineLimit(2)
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
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
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
            detailRow(icon: "shippingbox", label: "Количество", value: "\(item.quantity) шт.")

            let expStatus = item.expirationStatus()
            if expStatus != .noShelfLife {
                divider
                expirationRow(expStatus)
            }

            if let location = item.locationAddress, !location.isEmpty {
                divider
                detailRow(icon: "mappin.and.ellipse", label: "Местонахождение", value: location)
            }

            divider
            detailRow(icon: "clock", label: "Добавлено", value: item.createdAt.formatted(Self.dateFormat))
        }
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
