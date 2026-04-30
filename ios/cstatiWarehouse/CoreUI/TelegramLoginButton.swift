//
//  TelegramLoginButton.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct TelegramLoginButton: View {
    
    
    var title: String = "Войти через Telegram"
    var isLoading: Bool = false
    let action: () -> Void
    
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white.opacity(0.9))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(title)
                    .foregroundStyle(.white.opacity(0.9))
                    .font(font: .bold, size: 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 47)
            .contentShape(Rectangle())
        }
        .appGlass()
        .buttonStyle(.pressable)
        .disabled(isLoading)
        .appAnimation(AppAnimation.smooth, value: isLoading)
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        VStack(spacing: 16) {
            TelegramLoginButton(action: {})
            TelegramLoginButton(isLoading: true, action: {})
        }
        .padding(.horizontal, 22)
    }
}
