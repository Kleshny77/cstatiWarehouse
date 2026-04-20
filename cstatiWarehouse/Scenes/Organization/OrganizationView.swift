//
// OrganizationView.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import SwiftUI

struct OrganizationView: View {

    // MARK: Properties

    @Bindable var presenter: OrganizationPresenter

    @State private var renameDraft: String = ""

    init(presenter: OrganizationPresenter) {
        self.presenter = presenter
    }

    // MARK: Body

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if presenter.summary != nil {
                        infoCard
                        membersSection
                        dangerSection
                    } else if presenter.isLoading {
                        loadingPlaceholder
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable {
                presenter.refresh()
            }
        }
        .onAppear {
            presenter.viewDidAppear()
        }
        .sheet(item: $presenter.leaveConfirmation) { confirmation in
            GlassConfirmationSheet(
                title: "Выйти из организации?",
                message: "Вы перестанете видеть «\(confirmation.organization.name)» и её склад. Вас можно будет пригласить снова.",
                confirmTitle: "Выйти",
                cancelTitle: "Отмена",
                isDestructive: true,
                onConfirm: { presenter.confirmLeave() },
                onCancel: { presenter.cancelLeave() }
            )
        }
        .sheet(item: $presenter.deleteConfirmation) { confirmation in
            GlassConfirmationSheet(
                title: "Удалить организацию?",
                message: "«\(confirmation.organization.name)» будет удалена навсегда вместе со всем складом. Отменить это нельзя.",
                confirmTitle: "Удалить",
                cancelTitle: "Отмена",
                isDestructive: true,
                onConfirm: { presenter.confirmDelete() },
                onCancel: { presenter.cancelDelete() }
            )
        }
        .sheet(isPresented: $presenter.isRenaming, onDismiss: { renameDraft = "" }) {
            renameSheet
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") { presenter.errorMessage = nil }
        } message: {
            if let error = presenter.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: UI Configuration

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Организация")
                .font(font: .bold, size: 28)
                .defaultTextStyle()
            Text(subtitle)
                .font(font: .semiBold, size: 16)
                .secondaryTextStyle()
        }
        .appAnimation(AppAnimation.snap, value: presenter.summary?.id)
    }

    @ViewBuilder
    private var infoCard: some View {
        if let summary = presenter.summary {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: summary.organization.isPersonal ? "person.fill" : "building.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .appGlass(in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.organization.name)
                            .font(font: .bold, size: 18)
                            .defaultTextStyle()
                            .lineLimit(2)
                        Text(summary.role.title)
                            .font(font: .semiBold, size: 13)
                            .secondaryTextStyle()
                    }
                    Spacer()
                    if summary.role.canEditOrganization, !summary.organization.isPersonal {
                        Button {
                            renameDraft = summary.organization.name
                            presenter.renameRequested()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .appGlass(in: Circle())
                        }
                        .buttonStyle(.pressable)
                    }
                }
                infoRow(title: "ID", value: summary.organization.id.uuidString.prefix(8).lowercased() + "…")
                infoRow(title: "Тип", value: summary.organization.isPersonal ? "Персональная" : "Общая")
                infoRow(title: "Создана", value: formattedDate(summary.organization.createdAt))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(font: .semiBold, size: 13)
                .secondaryTextStyle()
            Spacer()
            Text(value)
                .font(font: .semiBold, size: 13)
                .defaultTextStyle()
                .lineLimit(1)
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Участники", count: presenter.memberRows.count)
            VStack(spacing: 8) {
                ForEach(presenter.memberRows) { row in
                    memberRow(row)
                }
            }
            .appAnimation(AppAnimation.smooth, value: presenter.memberRows)
        }
    }

    private func memberRow(_ row: OrganizationMemberRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.isCurrentUser ? "Вы" : shortenedID(row.member.userID))
                    .font(font: .bold, size: 14)
                    .defaultTextStyle()
                Text("с \(formattedDate(row.member.joinedAt))")
                    .font(font: .semiBold, size: 12)
                    .secondaryTextStyle()
            }
            Spacer()
            Text(row.member.role.title)
                .font(font: .semiBold, size: 12)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .appGlass(in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var dangerSection: some View {
        if let summary = presenter.summary {
            VStack(spacing: 10) {
                if summary.role == .owner, !summary.organization.isPersonal {
                    dangerButton(
                        title: "Удалить организацию",
                        icon: "trash",
                        action: { presenter.deleteRequested() }
                    )
                }
                if summary.role != .owner {
                    dangerButton(
                        title: "Выйти из организации",
                        icon: "rectangle.portrait.and.arrow.right",
                        action: { presenter.leaveRequested() }
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private func dangerButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.warning()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(font: .bold, size: 15)
                Spacer()
            }
            .foregroundStyle(Color.red.opacity(0.95))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var loadingPlaceholder: some View {
        HStack {
            ProgressView().tint(.white.opacity(0.8))
            Text("Загружаем…")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нет активной организации")
                .font(font: .bold, size: 18)
                .defaultTextStyle()
            Text("Откройте вкладку «Мой склад» и выберите или создайте организацию в переключателе сверху.")
                .font(font: .semiBold, size: 14)
                .secondaryTextStyle()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var renameSheet: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 18) {
                Text("Переименовать")
                    .font(font: .bold, size: 20)
                    .defaultTextStyle()
                GlassTextField(
                    placeholder: "Название",
                    text: $renameDraft
                )
                HStack(spacing: 10) {
                    Button {
                        presenter.cancelRename()
                    } label: {
                        Text("Отмена")
                            .foregroundStyle(.white.opacity(0.75))
                            .font(font: .bold, size: 15)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.pressable)

                    Button {
                        presenter.submitRename(renameDraft)
                    } label: {
                        Text("Сохранить")
                            .foregroundStyle(.white.opacity(0.95))
                            .font(font: .bold, size: 15)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.lowercased())
                .font(font: .semiBold, size: 18)
                .secondaryTextStyle()
            Spacer()
            Text("\(count)")
                .font(font: .regular, size: 18)
                .secondaryTextStyle()
                .contentTransition(.numericText())
                .appAnimation(AppAnimation.snap, value: count)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Private Methods

    private var subtitle: String {
        if let summary = presenter.summary {
            if summary.organization.isPersonal {
                return "Персональная — только вы"
            }
            return "Ваша роль: \(summary.role.title.lowercased())"
        }
        return "Управление складом группы"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.errorMessage = nil } }
        )
    }

    private func shortenedID(_ id: UUID) -> String {
        "user • " + id.uuidString.prefix(8).lowercased()
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "ru_RU"))
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.twoDigits)
        )
    }
}

#Preview {
    let coordinator = AppCoordinator()
    OrganizationAssembly.assemble(appCoordinator: coordinator)
}
