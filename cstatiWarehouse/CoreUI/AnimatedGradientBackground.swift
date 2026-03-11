//
//  AnimatedGradientBackground.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct GradientBackground: View {
  @State private var animateGradient = false
  
  var body: some View {
    LinearGradient(
      colors: [
        Color(hex: "#2C2C3E"),
        Color(hex: "#1C1C2E"),
        Color(hex: "#3D2C52"),
        Color(hex: "#2E1F3E")
      ],
      startPoint: animateGradient ? .topLeading : .bottomLeading,
      endPoint: animateGradient ? .bottomTrailing : .topTrailing
    )
    .ignoresSafeArea()
    .onAppear {
      withAnimation(
        .easeInOut(duration: 3)
        .repeatForever(autoreverses: true)
      ) {
        animateGradient.toggle()
      }
    }
  }
}
