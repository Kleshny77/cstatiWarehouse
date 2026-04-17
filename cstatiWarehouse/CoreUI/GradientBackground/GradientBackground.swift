//
//  GradientBackground.swift
//  cstatiWarehouse
//
//  Created by Артём on 28.03.2026.
//

import SwiftUI

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#2C2C3E"),
                Color(hex: "#1C1C2E"),
                Color(hex: "#3D2C52"),
                Color(hex: "#2E1F3E")
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview() {
    GradientBackground()
}
