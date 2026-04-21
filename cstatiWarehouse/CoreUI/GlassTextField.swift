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
    /// Если задан — стекло в `RoundedRectangle` с этим радиусом (как карточки/рулетки); иначе капсула.
    var roundedGlassCornerRadius: CGFloat? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    var isFocused: FocusState<Bool>.Binding? = nil
    var autocapitalization: TextInputAutocapitalization = .never

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

    @ViewBuilder
    private func applyFocus<V: View>(to view: V) -> some View {
        if let f = isFocused {
            view.focused(f)
        } else {
            view
        }
    }

    @ViewBuilder
    private func fieldGlass<Content: View>(_ content: Content) -> some View {
        if let r = roundedGlassCornerRadius {
            content.appGlass(in: RoundedRectangle(cornerRadius: r, style: .continuous))
        } else {
            content.appGlass()
        }
    }

    private var regularFieldView: some View {
        applyFocus(to:
            fieldGlass(
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
            )
            .textInputAutocapitalization(autocapitalization)
            .keyboardType(keyboardType)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
        )
    }

    private var secureFieldView: some View {
        ZStack(alignment: .trailing) {
            fieldGlass(
                Color.clear
                    .frame(maxWidth: useFullWidth ? .infinity : nil, minHeight: 47)
                    .frame(width: useFullWidth ? nil : 331, height: 47)
            )

            Group {
                if isPasswordVisible {
                    applyFocus(to:
                        TextField(
                            "",
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundColor(.white.opacity(0.4))
                                .font(font: .semiBold, size: 14)
                        )
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                    )
                } else {
                    applyFocus(to:
                        SecureField(
                            "",
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundColor(.white.opacity(0.4))
                                .font(font: .semiBold, size: 14)
                        )
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
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
            .textInputAutocapitalization(autocapitalization)

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
