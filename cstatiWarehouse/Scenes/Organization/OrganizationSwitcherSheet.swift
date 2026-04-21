//
// OrganizationSwitcherSheet.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import SwiftUI

/// Sheet для выбора активной организации, создания новой и (в будущем) вступления по коду.
/// Данные (список, состояния) приходят сверху — компонент сам ничего не грузит.
struct OrganizationSwitcherSheet: View {

    // MARK: Properties

    let organizations: [OrganizationSummary]
    let activeID: UUID?
    let isLoading: Bool
    let isCreating: Bool
    let isJoining: Bool
    let errorMessage: String?
    /// Краткое уведомление (например «уже в организации»), без красного баннера ошибки.
    let toastMessage: String?
    let onSelect: (OrganizationSummary) -> Void
    let onCreate: (String) -> Void
    let onJoin: (String) -> Void
    let onCancel: () -> Void
    let onDismissError: () -> Void
    let onDismissToast: () -> Void

    @State private var newOrgName: String = ""
    @State private var joinCode: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, code }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    listSection
                    joinSection
                    createSection
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, toastMessage == nil ? 40 : 72)
            }

            if let toast = toastMessage, !toast.isEmpty {
                Button {
                    AppHaptics.selection()
                    onDismissToast()
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(toast)
                            .font(font: .semiBold, size: 14)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: toastMessage)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(SheetPresentationChrome.organizationManagementGradient)
    }

    private var contentHeight: CGFloat {
        let rows = CGFloat(max(1, organizations.count)) * 60
        return 28 + 36 + 16 + rows + 16 + 70 + 16 + 70 + 40
    }

    // MARK: UI Configuration

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Организация")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 22)
                Text("Выберите активную или создайте новую")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 13)
            }
            Spacer()
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
        }
    }

    @ViewBuilder
    private var listSection: some View {
        if isLoading && organizations.isEmpty {
            HStack(spacing: 10) {
                ProgressView().tint(.white.opacity(0.8))
                Text("Загружаем…")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(font: .semiBold, size: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 8) {
                ForEach(organizations) { summary in
                    organizationRow(summary)
                }
            }
            .appAnimation(AppAnimation.smooth, value: organizations)
        }
    }

    private func organizationRow(_ summary: OrganizationSummary) -> some View {
        let isActive = summary.id == activeID
        return Button {
            AppHaptics.selection()
            onSelect(summary)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: summary.organization.isPersonal ? "person.fill" : "building.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .appGlass(in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.organization.name)
                        .foregroundStyle(.white.opacity(0.95))
                        .font(font: .bold, size: 15)
                        .lineLimit(1)
                    Text(summary.role.title)
                        .foregroundStyle(.white.opacity(0.6))
                        .font(font: .semiBold, size: 12)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Новая организация")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 13)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $newOrgName,
                    prompt: Text("Название")
                        .foregroundColor(.white.opacity(0.4))
                        .font(font: .semiBold, size: 14)
                )
                .tint(.white.opacity(0.8))
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 14)
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit(submitCreate)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .appGlass(in: Capsule())

                Button {
                    submitCreate()
                } label: {
                    Group {
                        if isCreating {
                            ProgressView().tint(.white.opacity(0.85))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled(isCreating || trimmedName.isEmpty)
            }
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Присоединиться по коду")
                .foregroundStyle(.white.opacity(0.8))
                .font(font: .semiBold, size: 13)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $joinCode,
                    prompt: Text("Код приглашения")
                        .foregroundColor(.white.opacity(0.4))
                        .font(font: .semiBold, size: 14)
                )
                .tint(.white.opacity(0.8))
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 14)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: .code)
                .submitLabel(.done)
                .onSubmit(submitJoin)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .appGlass(in: Capsule())

                Button {
                    submitJoin()
                } label: {
                    Group {
                        if isJoining {
                            ProgressView().tint(.white.opacity(0.85))
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled(isJoining || trimmedCode.isEmpty)
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red.opacity(0.9))
            Text(text)
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 13)
            Spacer()
            Button {
                onDismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Private Methods

    private var trimmedName: String {
        newOrgName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCode: String {
        joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func submitCreate() {
        let name = trimmedName
        guard !name.isEmpty, !isCreating else { return }
        AppHaptics.impact(.light)
        onCreate(name)
        newOrgName = ""
        focusedField = nil
    }

    private func submitJoin() {
        let code = trimmedCode
        guard !code.isEmpty, !isJoining else { return }
        AppHaptics.impact(.light)
        onJoin(code)
        joinCode = ""
        focusedField = nil
    }
}
