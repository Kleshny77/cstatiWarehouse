//
//  AppAnimation.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import SwiftUI
import UIKit

/// Единая анимационная палитра приложения.
///
/// Используется везде вместо сырых `.snappy` / `.smooth` / `.spring`, чтобы
/// переключения, появления/исчезновения и press-feedback выглядели цельно.
///
/// Если система просит `reduceMotion`, все токены схлопываются в быстрый линейный
/// переход без пружинных эффектов.
enum AppAnimation {

    /// Быстрая пружина для мелких state-переключений (чипы, бейджи, счётчики).
    static var snap: Animation { .snappy(duration: 0.28, extraBounce: 0.05) }

    /// Мягкая пружина для layout-изменений (появление подсказок, секций, секторов).
    static var smooth: Animation { .smooth(duration: 0.35, extraBounce: 0) }

    /// Максимально быстрый отклик для press-эффектов (scale/opacity на нажатии).
    static var tap: Animation { .spring(response: 0.22, dampingFraction: 0.72) }

    /// Плавный, но заметный переход для крупных изменений (переключение табов,
    /// смена экранов внутри одной сцены).
    static var scene: Animation { .smooth(duration: 0.45, extraBounce: 0.02) }

    /// Неспешный fade для декоративных элементов (анимированный градиент, спалш).
    static var ambient: Animation { .easeInOut(duration: 2.5) }

    /// Токен с учётом Reduce Motion. Если системный флаг включён — отдаёт короткий
    /// линейный переход без пружин.
    static func respectingReducedMotion(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : animation
    }
}

// MARK: - View helpers

extension View {
    /// Аналог `.animation(_, value:)`, автоматически учитывающий `accessibilityReduceMotion`.
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

// MARK: - Haptics

/// Тактильная обратная связь. Используем через статические методы, чтобы не плодить
/// сервисы и не завязывать на них ViewModel.
enum AppHaptics {

    /// Короткий селектор: переключение чипов / табов / изменений фильтра.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Успех операции (сохранили профиль, создали айтем).
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Предупреждение / валидация не прошла.
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Ошибка операции.
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Лёгкий удар — подтверждение нажатия (списание, удаление).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
