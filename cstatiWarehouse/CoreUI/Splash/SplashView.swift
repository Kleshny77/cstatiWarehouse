//
//  SplashView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
  let name: String
  let loopMode: LottieLoopMode

  func makeUIView(context: Context) -> UIView {
    let container = UIView()
    let animation = LottieAnimation.named(name)
    let animationView = LottieAnimationView(animation: animation)
    
    animationView.loopMode = loopMode
    animationView.contentMode = .scaleAspectFit
    animationView.play()
    animationView.translatesAutoresizingMaskIntoConstraints = false
    
    container.addSubview(animationView)
    
    NSLayoutConstraint.activate([
      animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      animationView.topAnchor.constraint(equalTo: container.topAnchor),
      animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    return container
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

struct SplashView: View {
  var body: some View {
    ZStack {
      LottieView(name: "SplashAnimation", loopMode: .playOnce)
        .background(.black)
    }
  }
}

struct RootView: View {
  @State private var showSplash = true

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if showSplash {
        SplashView()
          .transition(.opacity)
      } else {
        CoordinatorView()
          .transition(.opacity)
      }
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
        withAnimation(.easeOut(duration: 2)) {
          showSplash = false
        }
      }
    }
  }
}
