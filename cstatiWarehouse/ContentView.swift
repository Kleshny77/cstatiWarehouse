//
//  ContentView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 16.01.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
      ZStack {
        AnimatedGradientBackground()
        VStack {
          header
          loginForm
          footer
        }
      }
    }
  
  var header: some View {
    VStack {
      appIcon
      welcomeTitle
      welcomeSubtitle
    }
  }
  
  var appIcon: some View {
    Image("cstatiWarehouseIcon")
      .resizable()
      .frame(width: 80, height: 80)
      .cornerRadius(24)
  }
  
  var welcomeTitle: some View {
    Text("Добро welcome")
      .foregroundStyle(.white)
      .font(.bold, size: 50)
  }
  
  var welcomeSubtitle: some View {
    Text("Войдите в свой аккаунт")
      .foregroundStyle(.white)
  }
  
  var loginForm: some View {
    VStack {
      
    }
  }
  
  var footer: some View {
    VStack {
      
    }
  }
}

#Preview {
    ContentView()
}

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#2C2C3E"),  // Темно-серый сверху
                Color(hex: "#1C1C2E"),  // Еще темнее
                Color(hex: "#3D2C52"),  // Фиолетовый оттенок
                Color(hex: "#2E1F3E")   // Темно-фиолетовый снизу
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

// MARK: - Альтернативный вариант с более плавной анимацией
struct SmoothAnimatedGradient: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Базовый градиент
            LinearGradient(
                colors: [
                    Color(hex: "#2C2C3E"),
                    Color(hex: "#1C1C2E"),
                    Color(hex: "#3D2C52"),
                    Color(hex: "#2E1F3E")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Анимированный оверлей для эффекта движения
            LinearGradient(
                colors: [
                    Color(hex: "#3D2C52").opacity(0.3),
                    Color.clear,
                    Color(hex: "#2E1F3E").opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(y: offset)
            .blur(radius: 60)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                offset = 200
            }
        }
    }
}
