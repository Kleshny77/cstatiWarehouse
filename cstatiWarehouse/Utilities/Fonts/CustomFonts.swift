//
//  CustomFonts.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI
import UIKit

// MARK: - Font Names
enum CustomFonts: String, CaseIterable {
  case regular = "CenturyGothicPaneuropean"
  case bold = "CenturyGothicPaneuropean-Bold"
  case semiBold = "CenturyGothicPaneuropean-SemiBold"
  case light = "CenturyGothicPaneuropean-Light"
  case thin = "CenturyGothicPaneuropean-Thin"
  case black = "CenturyGothicPaneuropean-Black"
  case extraBold = "CenturyGothicPaneuropean-ExtraBold"
  
  case regularItalic = "CenturyGothicPaneuropean-Italic"
  case boldItalic = "CenturyGothicPaneuropean-BoldItalic"
  case semiBoldItalic = "CenturyGothicPaneuropean-SemiBoldIt"
  case lightItalic = "CenturyGothicPaneuropean-LightIt"
  case thinItalic = "CenturyGothicPaneuropean-ThinItalic"
  case blackItalic = "CenturyGothicPaneuropean-BlackIt"
  case extraBoldItalic = "CenturyGothicPaneuropean-XtraBoldIt"
  
  func font(size: CGFloat) -> UIFont {
    UIFont(name: self.rawValue, size: size) ?? .systemFont(ofSize: size)
  }
}


// MARK: - Font Sizes
enum FontSize: CGFloat {
  case title = 28
  case title2 = 22
  case title3 = 20
  case body = 14
}

// MARK: - SwiftUI Font
extension Font {
  static func custom(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> Font {
    Font.custom(customFont.rawValue, size: size)
  }
  
  static func custom(font customFont: CustomFonts, size fontSize: FontSize) -> Font {
    Font.custom(customFont.rawValue, size: fontSize.rawValue)
  }
}

// MARK: - UIKit UIFont
extension UIFont {
  static func custom(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> UIFont {
    customFont.font(size: size)
  }
  
  static func custom(font customFont: CustomFonts, size fontSize: FontSize) -> UIFont {
    customFont.font(size: fontSize.rawValue)
  }
}

// MARK: - SwiftUI Extensions
extension Text {
  func font(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> Text {
    font(Font.custom(font: customFont, size: size))
  }
  
  func font(font customFont: CustomFonts, size fontSize: FontSize) -> Text {
    font(Font.custom(font: customFont, size: fontSize))
  }
}

extension View {
  func font(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> some View {
    font(Font.custom(font: customFont, size: size))
  }
  
  func font(font customFont: CustomFonts, size fontSize: FontSize) -> some View {
    font(Font.custom(font: customFont, size: fontSize))
  }
}

// MARK: - UIKit Extensions
extension UILabel {
  func setFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
    font = .custom(font: customFont, size: size)
  }
  
  func setFont(font customFont: CustomFonts, size fontSize: FontSize) {
    font = .custom(font: customFont, size: fontSize)
  }
}

extension UIButton {
  func setTitleFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
    titleLabel?.font = .custom(font: customFont, size: size)
  }
  
  func setTitleFont(font customFont: CustomFonts, size fontSize: FontSize) {
    titleLabel?.font = .custom(font: customFont, size: fontSize)
  }
}

extension UITextField {
  func setFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
    font = .custom(font: customFont, size: size)
  }
  
  func setFont(font customFont: CustomFonts, size fontSize: FontSize) {
    font = .custom(font: customFont, size: fontSize)
  }
}

extension UITextView {
  func setFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
    font = .custom(font: customFont, size: size)
  }
  
  func setFont(font customFont: CustomFonts, size fontSize: FontSize) {
    font = .custom(font: customFont, size: fontSize)
  }
}
