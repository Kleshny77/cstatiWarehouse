//
//  WarehouseItemCard.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.03.2026.
//

import SwiftUI

struct WarehouseItemCard: View {
    var item: Item
    var isExpanded: Bool = false

    private var status: ExpirationStatus {
        item.expirationStatusConsideringVariants()
    }

    var body: some View {
        VStack(spacing: 0) {
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
                .shadow(color: item.isProductGroup ? Color.black.opacity(0.35) : .clear, radius: item.isProductGroup ? 10 : 0, y: item.isProductGroup ? 4 : 0)
                .background(alignment: .top) {
                    if item.isProductGroup { stackBackdrop }
                }
            if item.isProductGroup {
                Color.clear
                    .frame(height: Self.stackBottomReserve)
                    .accessibilityHidden(true)
            }
        }
    }

    private static let stackBottomReserve: CGFloat = 14

    private static let cardCornerRadius: CGFloat = 22

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            image
            titleAndDetailsColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var titleAndDetailsColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                Text(status.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(status.badgeColor))
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(0)
            }

            if item.isProductGroup {
                groupSubtitle
                HStack {
                    Spacer(minLength: 0)
                    expandChevron
                }
                .padding(.top, 2)
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
    }

    private var groupSubtitle: some View {
        HStack(spacing: 6) {
            if let liters = item.displayTotalLiters {
                Label("Всего \(formatLiters(liters))", systemImage: "drop.fill")
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

    private var stackBackdrop: some View {
        ZStack {
            ForEach(0 ..< Self.deckLayerSpecs.count, id: \.self) { index in
                deckLayer(Self.deckLayerSpecs[index])
            }
        }
        .allowsHitTesting(false)
        .compositingGroup()
    }

    private struct DeckLayerSpec {
        let offsetY: CGFloat
        let horizontalInset: CGFloat
        let fillOpacity: Double
    }

    private static let deckLayerSpecs: [DeckLayerSpec] = [
        DeckLayerSpec(offsetY: 11, horizontalInset: 10, fillOpacity: 0.038),
        DeckLayerSpec(offsetY: 5, horizontalInset: 4, fillOpacity: 0.055),
    ]

    private func deckLayer(_ spec: DeckLayerSpec) -> some View {
        RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(spec.fillOpacity))
            .padding(.horizontal, spec.horizontalInset)
            .offset(y: spec.offsetY)
    }

    private var image: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImageView(url: item.imageURL) {
                imagePlaceholder
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if let badge = item.stockBadgeText {
                Text(badge)
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
                Text(variantHeadline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !variantSubtitle.isEmpty {
                    Text(variantSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(status.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
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

    private var variantHeadline: String {
        let label = variant.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty {
            return label
        }
        if let liters = variant.liquidLitersEquivalent {
            return formatLiters(liters)
        }
        return "Без подписи"
    }

    private var variantSubtitle: String {
        let label = variant.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty {
            return variant.stockAccountingSummary
        }
        if variant.measureUnit == .milliliter && variant.volumePerUnit == nil {
            return ""
        }
        return variant.stockPackagingLine
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
