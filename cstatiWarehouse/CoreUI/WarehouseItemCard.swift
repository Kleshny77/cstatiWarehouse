//
//  WarehouseItemCard.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.03.2026.
//

import SwiftUI

struct WarehouseItemCard: View {
    var item: Item
    /// Группа развёрнута: chevron поворачивается, фон-«стопка» приподнимается визуально.
    var isExpanded: Bool = false

    private var status: ExpirationStatus {
        item.expirationStatusConsideringVariants()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if item.isProductGroup {
                stackBackdrop
            }
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            image
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(status.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(status.badgeColor))
                }

                if item.isProductGroup {
                    groupSubtitle
                } else if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.tail)
                } else if item.isVariantLine, !item.variantLabel.isEmpty {
                    Text(item.variantLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            if item.isProductGroup {
                expandChevron
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var groupSubtitle: some View {
        HStack(spacing: 6) {
            if let liters = item.displayTotalLiters {
                Label(formatLiters(liters), systemImage: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .labelStyle(.titleAndIcon)
                Text("·")
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(packagingsTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var packagingsTitle: String {
        let n = item.variants.filter { !$0.status.isArchived }.count
        let lastTwo = n % 100
        let suffix: String
        if (11...14).contains(lastTwo) {
            suffix = "вариантов"
        } else {
            switch n % 10 {
            case 1: suffix = "вариант"
            case 2, 3, 4: suffix = "варианта"
            default: suffix = "вариантов"
            }
        }
        return "\(n) \(suffix)"
    }

    private var expandChevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(0.08)))
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .appAnimation(AppAnimation.snap, value: isExpanded)
    }

    /// Два слоя позади карточки — лёгкая глубина без «тяжёлого» стека.
    private var stackBackdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .frame(height: 126)
                .padding(.horizontal, 11)
                .offset(y: 6)

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .frame(height: 128)
                .padding(.horizontal, 5)
                .offset(y: 3)
        }
        .allowsHitTesting(false)
    }

    private var image: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImageView(url: item.imageURL) {
                imagePlaceholder
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if let primary = item.quantityBadgePrimary {
                Text(quantityBadgeLine(primary: primary, suffix: item.quantityBadgeUnitSuffix))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(.blue))
                    .offset(x: 6, y: -6)
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: item.quantity)
            }
        }
    }

    private func quantityBadgeLine(primary: String, suffix: String?) -> String {
        if let suffix, !suffix.isEmpty {
            return "\(primary) \(suffix)"
        }
        return primary
    }

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
            Image(systemName: "shippingbox")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
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
}

// MARK: - VariantInlineRow

/// Inline-строка варианта в раскрытой группе. Тап ведёт в детальный экран этой строки.
struct VariantInlineRow: View {
    let variant: Item

    private var status: ExpirationStatus { variant.expirationStatus() }

    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: variant.imageURL) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: "shippingbox")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(variant.variantLabel.isEmpty ? "Без подписи" : variant.variantLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(quantityText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(status.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(status.badgeColor))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var quantityText: String {
        switch variant.measureUnit {
        case .liter:
            let vol = variant.volumePerUnit.map { formatLiters($0) } ?? "—"
            return "\(variant.quantity) упак. × \(vol)"
        case .piece:
            return "\(variant.quantity) шт."
        case .package:
            return "\(variant.quantity) упак."
        case .meter:
            return "\(variant.quantity) м"
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
}

#Preview {
    ZStack {
        GradientBackground()
        WarehouseItemCard(
            item: Item(
                name: "Хлеб",
                categoryName: "еда",
                quantity: 3,
                expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)
            )
        )
    }
}
