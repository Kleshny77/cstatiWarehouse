//
// LoginView.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import SwiftUI

struct LoginView: View {
    @Bindable var presenter: LoginPresenter
    @State private var email: String = ""
    @State private var password: String = ""

    @FocusState private var emailIsFocused: Bool
    @FocusState private var passwordIsFocused: Bool

    init(presenter: LoginPresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            VStack {
                header
                loginForm
                footer
            }
            .padding(.horizontal, 22)
        }
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
            appIcon
            welcome
        }
        .padding(.bottom, 35)
    }
    
    private var appIcon: some View {
        Image("cstatiWarehouseIcon")
            .resizable()
            .frame(width: 80, height: 80)
            .cornerRadius(24)
    }
    
    private var welcome: some View {
        VStack(spacing: 11) {
            welcomeTitle
            welcomeSubtitle
        }
    }
    
    private var welcomeTitle: some View {
        Text("Добро пожаловать")
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .extraBold, size: .title)
    }
    
    private var welcomeSubtitle: some View {
        Text("Войдите в свой аккаунт")
            .foregroundStyle(.white.opacity(0.5))
            .font(font: .semiBold, size: .title3)
    }
    
    private var loginForm: some View {
        VStack(spacing: 14) {
            GlassTextField(
                title: "Email",
                placeholder: "your@email.com",
                text: $email,
                keyboardType: .emailAddress,
                submitLabel: .next,
                onSubmit: { passwordIsFocused = true },
                isFocused: $emailIsFocused
            )
            GlassTextField(
                title: "Пароль",
                placeholder: "*******",
                text: $password,
                isSecure: true,
                submitLabel: .done,
                onSubmit: { presenter.loginButtonTapped(email: email, password: password) },
                isFocused: $passwordIsFocused
            )
        }
    }
    
    private var footer: some View {
        VStack(spacing: 16) {
            loginButton
            oauthSection
            textFooter
                .padding(.top, 6)
        }
        .padding(.top, 32)
    }

    private var oauthSection: some View {
        VStack(spacing: 12) {
            Button(action: { presenter.googleLoginButtonTapped() }) {
                HStack(spacing: 10) {
                    if presenter.isOAuthLoginInProgress {
                        ProgressView()
                            .tint(.white.opacity(0.9))
                    }
                    Text("Войти через Google")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(font: .bold, size: 14)
                }
                .frame(maxWidth: .infinity)
                .frame(width: 331, height: 47)
            }
            .appGlass()
            .buttonStyle(.pressable)
            .disabled(presenter.isOAuthLoginInProgress)
        }
    }

    private var loginButton: some View {
        Button(action: {
            presenter.loginButtonTapped(email: email, password: password)
        }) {
            Text("Войти")
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .bold, size: 14)
                .frame(maxWidth: .infinity)
                .frame(width: 331, height: 47)
        }
        .appGlass()
        .buttonStyle(.pressable)
    }
    
    private var textFooter: some View {
        HStack(spacing: 4) {
            Text("Нет аккаунта?")
                .foregroundStyle(.white.opacity(0.5))
                .font(font: .bold, size: 14)
            Button(action: {
                presenter.registerButtonTapped()
            }) {
                Text("Зарегистрироваться")
                    .foregroundStyle(Color(hex: "8A80FF"))
                    .font(font: .bold, size: 14)
            }
            .buttonStyle(.pressable)
        }
    }
}

#Preview {
    let coordinator = AppCoordinator()
    LoginAssembly.assemble(appCoordinator: coordinator)
}
