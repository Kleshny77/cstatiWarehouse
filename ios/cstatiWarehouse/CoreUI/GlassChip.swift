//
//  GlassChip.swift
//  cstatiWarehouse
//

import SwiftUI

struct GlassChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(font: .semiBold, size: 13)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.clear)
            )
            .appGlass(in: Capsule())
            .appAnimation(AppAnimation.snap, value: isSelected)
        }
        .buttonStyle(.pressable)
        .contentShape(Capsule())
    }
}
