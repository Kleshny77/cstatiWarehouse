//
//  WarehouseItemCard.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.03.2026.
//

import SwiftUI

struct WarehouseItemCard: View {
    var item: Item
    
    private var status: ExpirationStatus {
        item.expirationStatus()
    }
    
    var body: some View {
        HStack(alignment: .top) {
            image
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(status.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(status.badgeColor))
                }
                
                Text(item.description ?? "")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 140)
        .background(.clear)
    }
    
    private var image: some View {
        ZStack(alignment: .topTrailing) {
            Image("test")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            
            if item.quantity > 0 {
                Text("\(item.quantity)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(.blue)
                            .padding(3)
                    )
                    .offset(x: 8, y: -8)
            }
        }
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
