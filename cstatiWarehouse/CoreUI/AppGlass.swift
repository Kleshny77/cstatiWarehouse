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
            .scaleEffect(configuration.isPressed ? scaleOnPress : 1)
            .opacity(configuration.isPressed ? fadeOnPress : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
