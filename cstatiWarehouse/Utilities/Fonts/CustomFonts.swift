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
    case regular = "CenturyGothicRegular"
    case bold = "CenturyGothicBold"
    case semiBold = "CenturyGothicSemiBold"
    case light = "CenturyGothicLight"
    case thin = "CenturyGothicThin"
    case black = "CenturyGothicBlack"
    case extraBold = "CenturyGothicExtraBold"
    
    case italic = "CenturyGothicItalic"
    case boldItalic = "CenturyGothicBoldItalic"
    case semiBoldItalic = "CenturyGothicSemiBoldItalic"
    case lightItalic = "CenturyGothicLightItalic"
    case thinItalic = "CenturyGothicThinItalic"
    case blackItalic = "CenturyGothicBlackItalic"
    case extraBoldItalic = "CenturyGothicExtraBoldItalic"
    case regularItalic = "CenturyGothicRegularItalic"
    
    func font(size: CGFloat) -> UIFont {
        UIFont(name: self.rawValue, size: size) ?? .systemFont(ofSize: size)
    }
}

// MARK: - Font Sizes
enum FontSize: CGFloat {
    case largeTitle = 34
    case title = 28
    case title2 = 22
    case title3 = 20
    case body = 17
    case callout = 16
    case subheadline = 15
    case footnote = 13
    case caption = 12
    case caption2 = 11
}

// MARK: - Font Styles
enum AppFontStyle {
    case largeTitle, title, title2, title3, body, callout, subheadline, footnote, caption, caption2
    case largeTitleBold, titleBold, title2Bold, title3Bold, bodyBold, calloutBold, subheadlineBold
    case largeTitleLight, titleLight, bodyLight, subheadlineLight, captionLight
    case titleSemiBold, bodySemiBold, calloutSemiBold
    case bodyThin, subheadlineThin
    
    var config: (font: CustomFonts, size: FontSize) {
        switch self {
        case .largeTitle: return (.regular, .largeTitle)
        case .title: return (.regular, .title)
        case .title2: return (.regular, .title2)
        case .title3: return (.regular, .title3)
        case .body: return (.regular, .body)
        case .callout: return (.regular, .callout)
        case .subheadline: return (.regular, .subheadline)
        case .footnote: return (.regular, .footnote)
        case .caption: return (.regular, .caption)
        case .caption2: return (.regular, .caption2)
            
        case .largeTitleBold: return (.bold, .largeTitle)
        case .titleBold: return (.bold, .title)
        case .title2Bold: return (.bold, .title2)
        case .title3Bold: return (.bold, .title3)
        case .bodyBold: return (.bold, .body)
        case .calloutBold: return (.bold, .callout)
        case .subheadlineBold: return (.bold, .subheadline)
            
        case .largeTitleLight: return (.light, .largeTitle)
        case .titleLight: return (.light, .title)
        case .bodyLight: return (.light, .body)
        case .subheadlineLight: return (.light, .subheadline)
        case .captionLight: return (.light, .caption)
            
        case .titleSemiBold: return (.semiBold, .title)
        case .bodySemiBold: return (.semiBold, .body)
        case .calloutSemiBold: return (.semiBold, .callout)
            
        case .bodyThin: return (.thin, .body)
        case .subheadlineThin: return (.thin, .subheadline)
        }
    }
    
    var uiFont: UIFont {
        config.font.font(size: config.size.rawValue)
    }
    
    var swiftUIFont: Font {
        Font.custom(config.font.rawValue, size: config.size.rawValue)
    }
}

// MARK: - SwiftUI Font
extension Font {
    static func custom(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> Font {
        Font.custom(customFont.rawValue, size: size)
    }
    
    static func custom(font customFont: CustomFonts, size fontSize: FontSize) -> Font {
        Font.custom(customFont.rawValue, size: fontSize.rawValue)
    }
    
    static func app(style: AppFontStyle) -> Font {
        style.swiftUIFont
    }
    
    static let appLargeTitle = app(style: .largeTitle)
    static let appTitle = app(style: .title)
    static let appTitle2 = app(style: .title2)
    static let appTitle3 = app(style: .title3)
    static let appBody = app(style: .body)
    static let appCallout = app(style: .callout)
    static let appSubheadline = app(style: .subheadline)
    static let appFootnote = app(style: .footnote)
    static let appCaption = app(style: .caption)
    static let appCaption2 = app(style: .caption2)
    
    static let appLargeTitleBold = app(style: .largeTitleBold)
    static let appTitleBold = app(style: .titleBold)
    static let appTitle2Bold = app(style: .title2Bold)
    static let appTitle3Bold = app(style: .title3Bold)
    static let appBodyBold = app(style: .bodyBold)
    static let appCalloutBold = app(style: .calloutBold)
    static let appSubheadlineBold = app(style: .subheadlineBold)
    
    static let appLargeTitleLight = app(style: .largeTitleLight)
    static let appTitleLight = app(style: .titleLight)
    static let appBodyLight = app(style: .bodyLight)
    static let appSubheadlineLight = app(style: .subheadlineLight)
    static let appCaptionLight = app(style: .captionLight)
    
    static let appTitleSemiBold = app(style: .titleSemiBold)
    static let appBodySemiBold = app(style: .bodySemiBold)
    static let appCalloutSemiBold = app(style: .calloutSemiBold)
    
    static let appBodyThin = app(style: .bodyThin)
    static let appSubheadlineThin = app(style: .subheadlineThin)
}

// MARK: - UIKit UIFont
extension UIFont {
    static func custom(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> UIFont {
        customFont.font(size: size)
    }
    
    static func custom(font customFont: CustomFonts, size fontSize: FontSize) -> UIFont {
        customFont.font(size: fontSize.rawValue)
    }
    
    static func app(style: AppFontStyle) -> UIFont {
        style.uiFont
    }
    
    static let appLargeTitle = app(style: .largeTitle)
    static let appTitle = app(style: .title)
    static let appTitle2 = app(style: .title2)
    static let appTitle3 = app(style: .title3)
    static let appBody = app(style: .body)
    static let appCallout = app(style: .callout)
    static let appSubheadline = app(style: .subheadline)
    static let appFootnote = app(style: .footnote)
    static let appCaption = app(style: .caption)
    static let appCaption2 = app(style: .caption2)
    
    static let appLargeTitleBold = app(style: .largeTitleBold)
    static let appTitleBold = app(style: .titleBold)
    static let appTitle2Bold = app(style: .title2Bold)
    static let appTitle3Bold = app(style: .title3Bold)
    static let appBodyBold = app(style: .bodyBold)
    static let appCalloutBold = app(style: .calloutBold)
    static let appSubheadlineBold = app(style: .subheadlineBold)
    
    static let appLargeTitleLight = app(style: .largeTitleLight)
    static let appTitleLight = app(style: .titleLight)
    static let appBodyLight = app(style: .bodyLight)
    static let appSubheadlineLight = app(style: .subheadlineLight)
    static let appCaptionLight = app(style: .captionLight)
    
    static let appTitleSemiBold = app(style: .titleSemiBold)
    static let appBodySemiBold = app(style: .bodySemiBold)
    static let appCalloutSemiBold = app(style: .calloutSemiBold)
    
    static let appBodyThin = app(style: .bodyThin)
    static let appSubheadlineThin = app(style: .subheadlineThin)
}

// MARK: - SwiftUI Extensions
extension Text {
    func font(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> Text {
        font(Font.custom(font: customFont, size: size))
    }
    
    func font(font customFont: CustomFonts, size fontSize: FontSize) -> Text {
        font(Font.custom(font: customFont, size: fontSize))
    }
    
    func font(style: AppFontStyle) -> Text {
        font(style.swiftUIFont)
    }
}

extension View {
    func font(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) -> some View {
        font(Font.custom(font: customFont, size: size))
    }
    
    func font(font customFont: CustomFonts, size fontSize: FontSize) -> some View {
        font(Font.custom(font: customFont, size: fontSize))
    }
    
    func font(style: AppFontStyle) -> some View {
        font(style.swiftUIFont)
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
    
    func setFont(style: AppFontStyle) {
        font = style.uiFont
    }
}

extension UIButton {
    func setTitleFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
        titleLabel?.font = .custom(font: customFont, size: size)
    }
    
    func setTitleFont(font customFont: CustomFonts, size fontSize: FontSize) {
        titleLabel?.font = .custom(font: customFont, size: fontSize)
    }
    
    func setTitleFont(style: AppFontStyle) {
        titleLabel?.font = style.uiFont
    }
}

extension UITextField {
    func setFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
        font = .custom(font: customFont, size: size)
    }
    
    func setFont(font customFont: CustomFonts, size fontSize: FontSize) {
        font = .custom(font: customFont, size: fontSize)
    }
    
    func setFont(style: AppFontStyle) {
        font = style.uiFont
    }
}

extension UITextView {
    func setFont(font customFont: CustomFonts, size: CGFloat = FontSize.body.rawValue) {
        font = .custom(font: customFont, size: size)
    }
    
    func setFont(font customFont: CustomFonts, size fontSize: FontSize) {
        font = .custom(font: customFont, size: fontSize)
    }
    
    func setFont(style: AppFontStyle) {
        font = style.uiFont
    }
}
