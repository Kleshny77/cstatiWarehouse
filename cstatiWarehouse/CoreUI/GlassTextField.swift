//
//  GlassTextField.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct GlassTextField: View {
    var title: String? = nil
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    /// Когда `true`, поле растягивается по ширине контейнера (как на экранах с `padding(.horizontal, 20)`).
    /// По умолчанию — фиксированная ширина 331 (экраны входа/регистрации).
    var useFullWidth: Bool = false

    @State private var isPasswordVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.isEmpty {
                Text(title)
                    .foregroundStyle(.white.opacity(0.9))
                    .font(font: .semiBold, size: 14)
            }

            if isSecure {
                secureFieldView
            } else {
                regularFieldView
            }
        }
    }

    private var regularFieldView: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .foregroundColor(.white.opacity(0.4))
                .font(font: .semiBold, size: 14)
        )
        .tint(.white.opacity(0.8))
        .foregroundStyle(.white.opacity(0.8))
        .font(font: .semiBold, size: 14)
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: useFullWidth ? .infinity : nil, minHeight: 47)
        .frame(width: useFullWidth ? nil : 331, height: 47)
        .appGlass()
        .autocapitalization(.none)
        .keyboardType(keyboardType)
    }

    private var secureFieldView: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .frame(maxWidth: useFullWidth ? .infinity : nil, minHeight: 47)
                .frame(width: useFullWidth ? nil : 331, height: 47)
                .appGlass()

            Group {
                if isPasswordVisible {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder)
                            .foregroundColor(.white.opacity(0.4))
                            .font(font: .semiBold, size: 14)
                    )
                } else {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder)
                            .foregroundColor(.white.opacity(0.4))
                            .font(font: .semiBold, size: 14)
                    )
                }
            }
            .tint(.white.opacity(0.8))
            .foregroundStyle(.white.opacity(0.8))
            .font(font: .semiBold, size: 14)
            .padding(.leading, 17)
            .padding(.trailing, 55)
            .padding(.vertical, 15)
            .frame(maxWidth: useFullWidth ? .infinity : nil, minHeight: 47)
            .frame(width: useFullWidth ? nil : 331, height: 47)
            .autocapitalization(.none)

            Button(action: { isPasswordVisible.toggle() }) {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, 13)
        }
    }
}

#Preview {
    @Previewable @State var email: String = ""

    ZStack {
        GradientBackground()

        VStack(spacing: 30) {
            GlassTextField(
                title: "email",
                placeholder: "yourEmail@domen.com",
                text: $email,
                isSecure: false
            )

            GlassTextField(
                title: "email",
                placeholder: "yourPassword",
                text: $email,
                isSecure: true
            )
        }
    }
}
