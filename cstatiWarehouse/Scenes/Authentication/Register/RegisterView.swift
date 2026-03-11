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
  @State private var email: String = ""
  @State private var password: String = ""
  
  init(presenter: RegisterPresenter) {
    self.presenter = presenter
  }
  
  var body: some View {
    ZStack {
      GradientBackground()
      ScrollView {
          VStack(spacing: 0) {
            header
              .padding(.bottom, 24)
            registerForm
            footer
              .padding(.top, 24)
          }
          .padding(.horizontal, 22)
      }
    }
    .onChange(of: password) { _, newValue in
      _ = presenter.validatePassword(newValue)
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
    .padding(.top, 20)
    .padding(.bottom, 8)
  }
  
  private var appIcon: some View {
    Image("cstatiWarehouseIcon")
      .resizable()
      .frame(width: 80, height: 80)
      .cornerRadius(24)
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
      passwordRequirements
      registerButton
    }
  }
  
  private var passwordRequirements: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Требования к паролю:")
        .foregroundStyle(.white.opacity(0.7))
        .font(font: .semiBold, size: 12)
      requirementRow(met: presenter.passwordValidation.minLength, text: "Минимум 8 символов")
      requirementRow(met: presenter.passwordValidation.hasUppercase, text: "Заглавная буква (A-Z)")
      requirementRow(met: presenter.passwordValidation.hasLowercase, text: "Строчная буква (a-z)")
      requirementRow(met: presenter.passwordValidation.hasDigit, text: "Цифра (0-9)")
      requirementRow(met: presenter.passwordValidation.hasSpecialCharacter, text: "Спецсимвол (!@#$%^&*)")
    }
    .padding(.top, 4)
  }
  
  private func requirementRow(met: Bool, text: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(met ? Color(hex: "34C759") : Color(hex: "FF3B30"))
        .font(.system(size: 14))
      Text(text)
        .foregroundStyle(.white.opacity(0.8))
        .font(font: .semiBold, size: 12)
    }
  }
  
  private var registerButton: some View {
    Button(action: {
      presenter.registerButtonTapped(name: name, email: email, password: password)
    }) {
      Text("Зарегистрироваться")
        .foregroundStyle(.white.opacity(0.9))
        .font(font: .bold, size: 14)
        .frame(maxWidth: .infinity)
        .frame(height: 47)
    }
    .glassEffect()
    .padding(.top, 8)
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
