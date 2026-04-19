//
//  LoginView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct LoginView: View {
    @Bindable var presenter: LoginPresenter
    @State private var email: String = ""
    @State private var password: String = ""
    
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
                keyboardType: .emailAddress
            )
            
            GlassTextField(
                title: "Пароль",
                placeholder: "*******",
                text: $password,
                isSecure: true
            )
        }
    }
    
    private var footer: some View {
        VStack(spacing: 16) {
            loginButton
            divider
            TelegramLoginButton(
                isLoading: presenter.isTelegramLoginInProgress,
                action: {
                    presenter.telegramLoginButtonTapped()
                }
            )
            .frame(width: 331)
            textFooter
                .padding(.top, 6)
        }
        .padding(.top, 32)
    }
    
    private var divider: some View {
        HStack(spacing: 10) {
            dividerLine
            Text("или")
                .foregroundStyle(.white.opacity(0.45))
                .font(font: .semiBold, size: 12)
            dividerLine
        }
        .frame(width: 331)
    }
    
    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(height: 1)
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
