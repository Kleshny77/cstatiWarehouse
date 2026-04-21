//
//  RegisterView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct RegisterView: View {
    @Bindable var presenter: RegisterPresenter
    @State private var name: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var avatarImage: UIImage?
    @State private var isPhotoSheetPresented: Bool = false

    init(presenter: RegisterPresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.bottom, 24)
                    registerForm
                    footer
                        .padding(.top, 24)
                }
                .padding(.horizontal, 22)
                .appAnimation(AppAnimation.smooth, value: password.isEmpty)
            }
        }
        .onChange(of: password) { _, newValue in
            _ = presenter.validatePassword(newValue)
        }
        .photoSourcePicker(
            isPresented: $isPhotoSheetPresented,
            allowRemoval: avatarImage != nil,
            onPicked: { image in avatarImage = image },
            onRemove: { avatarImage = nil }
        )
        .alert("Ошибка", isPresented: .constant(presenter.errorMessage != nil)) {
            Button("OK") {
                presenter.errorMessage = nil
            }
        } message: {
            if let error = presenter.errorMessage {
                Text(error)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 26) {
            avatarPicker
            welcome
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var avatarPicker: some View {
        Button {
            isPhotoSheetPresented = true
        } label: {
            ZStack {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .appGlass(in: Circle())
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("фото")
                            .font(font: .semiBold, size: 12)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 100, height: 100)
                    .appGlass(in: Circle())
                }
            }
        }
        .buttonStyle(.pressable)
    }
    
    private var welcome: some View {
        VStack(spacing: 11) {
            Text("Регистрация")
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .extraBold, size: .title)
            Text("Создайте новый аккаунт")
                .foregroundStyle(.white.opacity(0.5))
                .font(font: .semiBold, size: .title3)
        }
    }
    
    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassTextField(
                title: "Имя",
                placeholder: "Ваше имя",
                text: $name
            )
            GlassTextField(
                title: "Фамилия",
                placeholder: "Ваша фамилия",
                text: $lastName
            )
            GlassTextField(
                title: "Email",
                placeholder: "your@email.com",
                text: $email,
                keyboardType: .emailAddress
            )
            GlassTextField(
                title: "Пароль",
                placeholder: "*******",
                text: $password,
                isSecure: true
            )
            if !password.isEmpty {
                passwordStrength
                    .transition(.opacity)
            }
            registerButton
            telegramSection
        }
        .frame(maxWidth: 331)
    }
    
    private var passwordStrength: some View {
        let score = passwordScore
        let isValid = presenter.passwordValidation.isValid
        let tint = strengthTint(for: score)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < score ? tint : Color.white.opacity(0.1))
                        .frame(height: 4)
                }
            }
            HStack(spacing: 6) {
                if isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.success)
                        .font(.system(size: 12))
                    Text("Пароль надёжный")
                        .foregroundStyle(.white.opacity(0.75))
                        .font(font: .semiBold, size: 12)
                } else {
                    Text("Добавьте: \(missingPasswordRequirements.joined(separator: ", "))")
                        .foregroundStyle(.white.opacity(0.55))
                        .font(font: .semiBold, size: 12)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
        .appAnimation(AppAnimation.snap, value: score)
        .appAnimation(AppAnimation.snap, value: isValid)
    }

    private var passwordScore: Int {
        let v = presenter.passwordValidation
        return [v.minLength, v.hasUppercase, v.hasLowercase, v.hasDigit, v.hasSpecialCharacter]
            .filter { $0 }
            .count
    }

    private var missingPasswordRequirements: [String] {
        let v = presenter.passwordValidation
        var items: [String] = []
        if !v.minLength { items.append("8 символов") }
        if !v.hasUppercase { items.append("заглавную") }
        if !v.hasLowercase { items.append("строчную") }
        if !v.hasDigit { items.append("цифру") }
        if !v.hasSpecialCharacter { items.append("спецсимвол") }
        return items
    }

    private func strengthTint(for score: Int) -> Color {
        switch score {
        case 0...2: return Color.error
        case 3...4: return Color.warning
        default: return Color.success
        }
    }
    
    private var registerButton: some View {
        Button(action: {
            presenter.registerButtonTapped(name: name, lastName: lastName, email: email, password: password, avatar: avatarImage)
        }) {
            Text("Зарегистрироваться")
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .bold, size: 14)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
        }
        .appGlass()
        .buttonStyle(.pressable)
        .padding(.top, 8)
    }
    
    private var telegramSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                dividerLine
                Text("или")
                    .foregroundStyle(.white.opacity(0.45))
                    .font(font: .semiBold, size: 12)
                dividerLine
            }
            TelegramLoginButton(
                title: "Зарегистрироваться через Telegram",
                isLoading: presenter.isTelegramLoginInProgress,
                action: {
                    presenter.telegramLoginButtonTapped()
                }
            )
        }
        .padding(.top, 4)
    }
    
    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(height: 1)
    }
    
    private var footer: some View {
        HStack(spacing: 4) {
            Text("Уже есть аккаунт?")
                .foregroundStyle(.white.opacity(0.5))
                .font(font: .bold, size: 14)
            Button(action: {
                presenter.loginButtonTapped()
            }) {
                Text("Войти")
                    .foregroundStyle(Color(hex: "8A80FF"))
                    .font(font: .bold, size: 14)
            }
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    let coordinator = AppCoordinator()
    RegisterAssembly.assemble(appCoordinator: coordinator)
}
