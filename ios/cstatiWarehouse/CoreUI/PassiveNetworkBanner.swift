//
// PassiveNetworkBanner.swift
// cstatiWarehouse
//

import SwiftUI

struct PassiveNetworkBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(message)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                AppHaptics.impact(.light)
                onRetry()
            } label: {
                Text("Повторить")
                    .font(font: .semiBold, size: 13)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.pressable)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.pressable)
        }
        .padding(14)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
