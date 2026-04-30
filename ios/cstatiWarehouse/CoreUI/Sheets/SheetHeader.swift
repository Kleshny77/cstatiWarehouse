//
//  SheetHeader.swift
//  cstatiWarehouse
//

import SwiftUI

struct SheetHeader: View {
    let title: String
    let subtitle: String?
    let onClose: (() -> Void)?

    init(title: String, subtitle: String? = nil, onClose: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 22)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.white.opacity(0.6))
                        .font(font: .semiBold, size: 13)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
            }
        }
    }
}
