//
//  AppGlass.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

extension View {
    func appGlass<S: Shape>(in shape: S) -> some View {
        self.glassEffect(.clear.tint(.black.opacity(0.5)), in: shape)
    }
    
    func appGlass() -> some View {
        self.appGlass(in: Capsule())
    }
}

// MARK: - PressableButtonStyle

struct PressableButtonStyle: ButtonStyle {
    var scaleOnPress: CGFloat = 0.96
    var fadeOnPress: Double = 0.85
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Глобально расширяем hit-area до всего контейнера label.
            // Это решает кейсы, когда тач ловится только по тексту/иконке.
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scaleOnPress : 1)
            .opacity(configuration.isPressed ? fadeOnPress : 1)
            .animation(AppAnimation.tap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Sheet presentation (как у переключателя организаций)

enum SheetPresentationChrome {
    /// Фон модальных шторок управления организацией / форм на градиенте.
    static let organizationManagementGradient = LinearGradient(
        colors: [
            Color(hex: "#2C2C3E"),
            Color(hex: "#1C1C2E"),
            Color(hex: "#3D2C52"),
            Color(hex: "#2E1F3E")
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}
