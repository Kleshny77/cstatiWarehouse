//
//  CustomColors.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI
import UIKit

// MARK: - App Colors
extension Color {
    static let brandPrimary = Color.adaptive(light: "#5C6F68", dark: "#5C6F68")
    static let brandSecondary = Color.adaptive(light: "#8AA39B", dark: "#8AA39B")
    static let brandAccent = Color.adaptive(light: "#95D9C3", dark: "#95D9C3")
    static let brandLight = Color.adaptive(light: "#A4F9C8", dark: "#A4F9C8")
    static let brandLightest = Color.adaptive(light: "#A7FFF6", dark: "#A7FFF6")
    
    static let textPrimary = Color.adaptive(light: "#FFFFFF", dark: "#FFFFFF")
    static let textSecondary = Color.adaptive(light: "#B0B0B0", dark: "#B0B0B0")
    static let textTertiary = Color.adaptive(light: "#808080", dark: "#808080")
    static let textDisabled = Color.adaptive(light: "#505050", dark: "#505050")
    static let textInverse = Color.adaptive(light: "#000000", dark: "#000000")
    
    static let backgroundPrimary = Color.adaptive(light: "#1C1C1E", dark: "#000000")
    static let backgroundSecondary = Color.adaptive(light: "#2C2C2E", dark: "#1C1C1E")
    static let backgroundTertiary = Color.adaptive(light: "#3A3A3C", dark: "#2C2C2E")
    static let backgroundCard = Color.adaptive(light: "#2C2C2E", dark: "#1C1C1E")
    
    static let separator = Color.adaptive(light: "#38383A", dark: "#38383A")
    static let border = Color.adaptive(light: "#48484A", dark: "#48484A")
    static let shadow = Color.adaptive(light: "#000000", dark: "#000000")
    
    static let success = Color.adaptive(light: "#34C759", dark: "#30D158")
    static let warning = Color.adaptive(light: "#FF9500", dark: "#FF9F0A")
    static let error = Color.adaptive(light: "#FF3B30", dark: "#FF453A")
    static let info = Color.adaptive(light: "#007AFF", dark: "#0A84FF")
    
    static let buttonPrimary = Color.brandAccent
    static let buttonSecondary = Color.adaptive(light: "#3A3A3C", dark: "#2C2C2E")
    static let buttonDisabled = Color.adaptive(light: "#2C2C2E", dark: "#1C1C1E")
    
    @available(*, deprecated, renamed: "brandPrimary")
    static let feldgrauApp = Color.brandPrimary
    
    @available(*, deprecated, renamed: "brandSecondary")
    static let cambridgeBlueApp = Color.brandSecondary
    
    @available(*, deprecated, renamed: "brandAccent")
    static let tiffanyBlueApp = Color.brandAccent
    
    @available(*, deprecated, renamed: "brandLight")
    static let aquamarineApp = Color.brandLight
    
    @available(*, deprecated, renamed: "brandLightest")
    static let iceBlueApp = Color.brandLightest
}

// MARK: - Color Helpers
extension Color {
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: .adaptiveColor(lightHex: light, darkHex: dark))
    }
    
    init(hex: String, alpha: Double = 1) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }

        let scanner = Scanner(string: cString)
        scanner.currentIndex = scanner.string.startIndex
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let red = (rgbValue & 0xFF0000) >> 16
        let green = (rgbValue & 0xFF00) >> 8
        let blue = rgbValue & 0xFF
        
        self.init(
            .sRGB,
            red: Double(red) / 0xFF,
            green: Double(green) / 0xFF,
            blue: Double(blue) / 0xFF,
            opacity: alpha
        )
    }
    
    init(uiColor: UIColor) {
        self.init(UIColor { traitCollection -> UIColor in
            return uiColor
        })
    }
    
    func lighter(by percentage: CGFloat = 0.3) -> Color {
        Color(uiColor: UIColor(self).adjust(by: abs(percentage)))
    }
    
    func darker(by percentage: CGFloat = 0.3) -> Color {
        Color(uiColor: UIColor(self).adjust(by: -abs(percentage)))
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let red, green, blue: UInt64
        switch hex.count {
        case 3:
            (red, green, blue) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (red, green, blue) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (red, green, blue) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (red, green, blue) = (0, 0, 0)
        }
        
        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: alpha
        )
    }
    
    static func adaptiveColor(lightHex: String, darkHex: String) -> UIColor {
        UIColor { traitCollection -> UIColor in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(hex: darkHex)
            default:
                return UIColor(hex: lightHex)
            }
        }
    }
    
    func adjust(by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(
            red: min(red + percentage, 1.0),
            green: min(green + percentage, 1.0),
            blue: min(blue + percentage, 1.0),
            alpha: alpha
        )
    }
}

extension View {
    func defaultTextStyle() -> some View {
        self.foregroundStyle(Color.textPrimary)
    }
    
    func secondaryTextStyle() -> some View {
        self.foregroundStyle(Color.textSecondary)
    }
    
    func tertiaryTextStyle() -> some View {
        self.foregroundStyle(Color.textTertiary)
    }
}
