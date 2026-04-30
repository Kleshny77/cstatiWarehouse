//
// DesignSystem.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import SwiftUI

enum DesignSystem {
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 4
        
        static let xs: CGFloat = 8
        
        static let sm: CGFloat = 12
        
        static let md: CGFloat = 16
        
        static let lg: CGFloat = 20
        
        static let xl: CGFloat = 24
        
        static let xxl: CGFloat = 32
        
        static let xxxl: CGFloat = 40
        
        static let huge: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let xs: CGFloat = 4
        
        static let sm: CGFloat = 8
        
        static let md: CGFloat = 12
        
        static let lg: CGFloat = 16
        
        static let xl: CGFloat = 20
        
        static let xxl: CGFloat = 24
        
        static let full: CGFloat = 9999
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let sm: CGFloat = 16
        
        static let md: CGFloat = 20
        
        static let lg: CGFloat = 24
        
        static let xl: CGFloat = 32
        
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Animation Duration
    
    enum AnimationDuration {
        static let fast: Double = 0.15
        
        static let normal: Double = 0.25
        
        static let slow: Double = 0.35
    }
    
    // MARK: - Opacity
    
    enum Opacity {
        static let subtle: Double = 0.1
        
        static let light: Double = 0.3
        
        static let medium: Double = 0.5
        
        static let strong: Double = 0.7
        
        static let intense: Double = 0.9
    }
}

// MARK: - Convenience Extensions

extension EdgeInsets {
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    
    static func symmetric(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
