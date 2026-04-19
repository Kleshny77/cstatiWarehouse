//
//  SettingsView.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var presenter: SettingsPresenter

    @State private var isPhotoSheetPresented: Bool = false

    init(presenter: SettingsPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    profileCard
                    if presenter.user != nil {
                        saveButton
                    }
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
        }
        .photoSourcePicker(
            isPresented: $isPhotoSheetPresented,
            allowRemoval: presenter.user?.avatarURL != nil || presenter.pickedAvatar != nil,
            onPicked: { image in
                presenter.pickedAvatar = image
                presenter.removeAvatarRequested = false
            },
            onRemove: {
                presenter.pickedAvatar = nil
                presenter.removeAvatarRequested = true
            }
        )
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") { presenter.errorMessage = nil }
        } message: {
            if let message = presenter.errorMessage { Text(message) }
        }
        .alert("Готово", isPresented: successBinding) {
            Button("OK") { presenter.successMessage = nil }
        } message: {
            if let message = presenter.successMessage { Text(message) }
        }
    }

    // MARK: UI Configuration

    private var header: some View {
        Text("Профиль")
            .foregroundStyle(.white.opacity(0.9))
            .font(font: .extraBold, size: .title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var profileCard: some View {
        if let user = presenter.user {
            VStack(spacing: 16) {
                avatarButton(for: user)
                nameField
                Text(user.email)
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 14)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .appGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Text("Нет активной сессии")
                .foregroundStyle(.white.opacity(0.6))
                .font(font: .semiBold, size: 14)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func avatarButton(for user: User) -> some View {
        Button {
            isPhotoSheetPresented = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                avatarContent(for: user)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .appGlass(in: Circle())

                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.35), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private func avatarContent(for user: User) -> some View {
        if let picked = presenter.pickedAvatar {
            Image(uiImage: picked)
                .resizable()
                .scaledToFill()
        } else if !presenter.removeAvatarRequested, let url = user.avatarURL {
            RemoteImageView(url: url) {
                initialsView(for: user)
            }
        } else {
            initialsView(for: user)
        }
    }

    private func initialsView(for user: User) -> some View {
        Text(initials(for: user))
            .foregroundStyle(.white.opacity(0.95))
            .font(font: .extraBold, size: 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func initials(for user: User) -> String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2,
           let first = parts.first?.first,
           let second = parts[1].first {
            return (String(first) + String(second)).uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    private var nameField: some View {
        GlassTextField(
            title: "Имя",
            placeholder: "Имя",
            text: $presenter.draftName
        )
    }

    private var saveButton: some View {
        Button {
            presenter.saveButtonTapped()
        } label: {
            HStack(spacing: 10) {
                if presenter.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(presenter.isSaving ? "Сохраняем..." : "Сохранить")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 15)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(!presenter.hasPendingChanges || presenter.isSaving)
        .opacity(presenter.hasPendingChanges ? 1 : 0.5)
    }

    private var logoutButton: some View {
        Button {
            presenter.logoutButtonTapped()
        } label: {
            Text("Выйти")
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .bold, size: 15)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .appGlass()
        .buttonStyle(.pressable)
    }

    // MARK: Private Methods

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.errorMessage = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { presenter.successMessage != nil },
            set: { if !$0 { presenter.successMessage = nil } }
        )
    }
}

#Preview {
    let coordinator = AppCoordinator()
    SettingsAssembly.assemble(appCoordinator: coordinator)
}
