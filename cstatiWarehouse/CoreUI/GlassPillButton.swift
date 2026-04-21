//
//  GlassPillButton.swift
//  cstatiWarehouse
//

import SwiftUI

/// Широкая glass-кнопка на всю ширину: используется как primary/secondary
/// в футерах шторок (Применить / Сбросить / Создать / Отмена и т.д.).
struct GlassPillButton: View {
    enum Role {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var role: Role = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    init(
        _ title: String,
        role: Role = .primary,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            guard !isLoading, isEnabled else { return }
            switch role {
            case .primary:     AppHaptics.impact(.light)
            case .secondary:   AppHaptics.selection()
            case .destructive: AppHaptics.warning()
            }
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .foregroundStyle(textColor)
                    .font(font: .bold, size: 15)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.pressable)
        .disabled(isLoading || !isEnabled)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var textColor: Color {
        switch role {
        case .primary:     return .white.opacity(0.95)
        case .secondary:   return .white.opacity(0.75)
        case .destructive: return Color.red.opacity(0.95)
        }
    }
}
