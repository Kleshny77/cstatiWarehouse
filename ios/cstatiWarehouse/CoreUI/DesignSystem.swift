//
// DesignSystem.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import SwiftUI

/// Централизованная система дизайна приложения
/// Содержит константы для spacing, colors, typography и других UI элементов
enum DesignSystem {
    
    // MARK: - Spacing
    
    /// Стандартные отступы приложения
    /// Используйте эти константы вместо magic numbers для консистентности UI
    enum Spacing {
        /// 4pt - минимальный отступ
        static let xxs: CGFloat = 4
        
        /// 8pt - очень маленький отступ
        static let xs: CGFloat = 8
        
        /// 12pt - маленький отступ
        static let sm: CGFloat = 12
        
        /// 16pt - стандартный отступ (наиболее часто используемый)
        static let md: CGFloat = 16
        
        /// 20pt - средний отступ
        static let lg: CGFloat = 20
        
        /// 24pt - большой отступ
        static let xl: CGFloat = 24
        
        /// 32pt - очень большой отступ
        static let xxl: CGFloat = 32
        
        /// 40pt - огромный отступ
        static let xxxl: CGFloat = 40
        
        /// 48pt - максимальный отступ
        static let huge: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    /// Радиусы скругления углов
    enum CornerRadius {
        /// 4pt - минимальное скругление
        static let xs: CGFloat = 4
        
        /// 8pt - маленькое скругление
        static let sm: CGFloat = 8
        
        /// 12pt - стандартное скругление
        static let md: CGFloat = 12
        
        /// 16pt - среднее скругление
        static let lg: CGFloat = 16
        
        /// 20pt - большое скругление
        static let xl: CGFloat = 20
        
        /// 24pt - очень большое скругление
        static let xxl: CGFloat = 24
        
        /// Полное скругление (капсула)
        static let full: CGFloat = 9999
    }
    
    // MARK: - Icon Sizes
    
    /// Размеры иконок
    enum IconSize {
        /// 16pt - маленькая иконка
        static let sm: CGFloat = 16
        
        /// 20pt - стандартная иконка
        static let md: CGFloat = 20
        
        /// 24pt - средняя иконка
        static let lg: CGFloat = 24
        
        /// 32pt - большая иконка
        static let xl: CGFloat = 32
        
        /// 48pt - очень большая иконка
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Animation Duration
    
    /// Длительность анимаций
    enum AnimationDuration {
        /// 0.15s - быстрая анимация
        static let fast: Double = 0.15
        
        /// 0.25s - стандартная анимация
        static let normal: Double = 0.25
        
        /// 0.35s - медленная анимация
        static let slow: Double = 0.35
    }
    
    // MARK: - Opacity
    
    /// Уровни прозрачности
    enum Opacity {
        /// 0.1 - очень слабая
        static let subtle: Double = 0.1
        
        /// 0.3 - слабая
        static let light: Double = 0.3
        
        /// 0.5 - средняя
        static let medium: Double = 0.5
        
        /// 0.7 - сильная
        static let strong: Double = 0.7
        
        /// 0.9 - очень сильная
        static let intense: Double = 0.9
    }
}

// MARK: - Convenience Extensions

extension EdgeInsets {
    /// Создаёт EdgeInsets с одинаковыми отступами со всех сторон
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    
    /// Создаёт EdgeInsets с горизонтальными и вертикальными отступами
    static func symmetric(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
