//
//  AppAnimation.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import SwiftUI
import UIKit

enum AppAnimation {

    static var snap: Animation { .snappy(duration: 0.28, extraBounce: 0.05) }

    static var smooth: Animation { .smooth(duration: 0.35, extraBounce: 0) }

    static var tap: Animation { .spring(response: 0.22, dampingFraction: 0.72) }

    static var scene: Animation { .smooth(duration: 0.45, extraBounce: 0.02) }

    static var ambient: Animation { .easeInOut(duration: 2.5) }

    static func respectingReducedMotion(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : animation
    }
}


extension View {
    func appAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAwareAnimation(base: animation, value: value))
    }
}

private struct ReduceMotionAwareAnimation<V: Equatable>: ViewModifier {
    let base: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            AppAnimation.respectingReducedMotion(base, reduceMotion: reduceMotion),
            value: value
        )
    }
}


enum AppHaptics {

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
