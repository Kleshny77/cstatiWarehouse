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
                    if let summary = presenter.summary {
                        infoCard
                        if summary.role.canManageMembers {
                            invitesButton
                        }
                        membersSection
                        manageSection
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
        .sheet(isPresented: $presenter.isInviteSheetPresented) {
            InvitesSheet(presenter: presenter)
        }
        .sheet(isPresented: $presenter.isEventsSheetPresented) {
            EventsSheet(presenter: presenter)
        }
        .sheet(isPresented: $presenter.isCategoriesSheetPresented) {
            CategoriesSheet(presenter: presenter)
        }
        .sheet(isPresented: $presenter.isActivitySheetPresented) {
            ActivitySheet(presenter: presenter)
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") { presenter.errorMessage = nil }
        } message: {
            if let error = presenter.errorMessage {
                Text(error)
            }
        }
        .alert("Готово", isPresented: infoBinding) {
            Button("OK") { presenter.infoMessage = nil }
        } message: {
            if let info = presenter.infoMessage {
                Text(info)
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
            memberAvatar(row.member)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: row))
                    .font(font: .bold, size: 14)
                    .defaultTextStyle()
                Text(displaySubtitle(for: row))
                    .font(font: .semiBold, size: 12)
                    .secondaryTextStyle()
                    .lineLimit(1)
            }
            Spacer()
            Text(row.member.role.title)
                .font(font: .semiBold, size: 12)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .appGlass(in: Capsule())

            if shouldShowMemberMenu(for: row) {
                Menu {
                    memberMenuItems(for: row)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .appGlass(in: Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func memberAvatar(_ member: OrganizationMember) -> some View {
        if let url = member.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
        }
    }

    private func shouldShowMemberMenu(for row: OrganizationMemberRow) -> Bool {
        guard let summary = presenter.summary else { return false }
        guard summary.role.canManageMembers else { return false }
        if row.isCurrentUser { return false }
        if row.member.role == .owner { return false }
        return true
    }

    @ViewBuilder
    private func memberMenuItems(for row: OrganizationMemberRow) -> some View {
        if let summary = presenter.summary {
            if summary.role == .owner {
                switch row.member.role {
                case .member:
                    Button("Сделать админом") { presenter.promoteToAdmin(row.member) }
                case .admin:
                    Button("Снять до участника") { presenter.demoteToMember(row.member) }
                case .owner:
                    EmptyView()
                }
                if !summary.organization.isPersonal {
                    Button("Передать владение") { presenter.transferOwnership(to: row.member) }
                }
            }
            Button(role: .destructive) {
                presenter.removeMember(row.member)
            } label: {
                Text("Удалить")
            }
        }
    }

    private var invitesButton: some View {
        Button {
            AppHaptics.impact(.light)
            presenter.inviteSheetRequested()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                Text("Приглашения")
                    .font(font: .bold, size: 15)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var manageSection: some View {
        VStack(spacing: 10) {
            manageButton(
                title: "Мероприятия",
                icon: "calendar",
                action: { presenter.eventsSheetRequested() }
            )
            manageButton(
                title: "Категории",
                icon: "tag",
                action: { presenter.categoriesSheetRequested() }
            )
            manageButton(
                title: "Журнал активности",
                icon: "clock.arrow.circlepath",
                action: { presenter.activitySheetRequested() }
            )
        }
    }

    private func manageButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(font: .bold, size: 15)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var infoBinding: Binding<Bool> {
        Binding(
            get: { presenter.infoMessage != nil },
            set: { if !$0 { presenter.infoMessage = nil } }
        )
    }

    private func shortenedID(_ id: UUID) -> String {
        "user • " + id.uuidString.prefix(8).lowercased()
    }

    private func displayName(for row: OrganizationMemberRow) -> String {
        if row.isCurrentUser { return "Вы" }
        let name = row.member.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        if let email = row.member.email, !email.isEmpty { return email }
        return shortenedID(row.member.userID)
    }

    private func displaySubtitle(for row: OrganizationMemberRow) -> String {
        let joined = "с \(formattedDate(row.member.joinedAt))"
        if row.isCurrentUser, let email = row.member.email, !email.isEmpty {
            return "\(email) · \(joined)"
        }
        if let email = row.member.email, !email.isEmpty, row.member.name != nil {
            return "\(email) · \(joined)"
        }
        return joined
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

// MARK: - InvitesSheet

private struct InvitesSheet: View {

    @Bindable var presenter: OrganizationPresenter
    @State private var expiresInDays: Int? = 7
    @State private var maxUses: Int? = nil

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    createCard

                    if presenter.isLoadingInvites && presenter.invites.isEmpty {
                        skeletonList
                    } else if presenter.invites.isEmpty {
                        emptyState
                    } else {
                        ForEach(presenter.invites) { invite in
                            inviteRow(invite)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var skeletonList: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                inviteRow(Self.skeletonInvite)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private static let skeletonInvite = OrganizationInvite(
        id: UUID(),
        organizationID: UUID(),
        code: "XXXXXX",
        createdByID: UUID(),
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 7),
        maxUses: 5,
        usedCount: 0,
        revokedAt: nil,
        isActive: true
    )

    private var header: some View {
        HStack {
            Text("Приглашения")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer()
            Button("Готово") { presenter.dismissInviteSheet() }
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 15)
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новый код")
                .font(font: .bold, size: 16)
                .defaultTextStyle()

            expiresPicker

            usesPicker

            Button {
                AppHaptics.impact(.medium)
                presenter.createInvite(expiresInDays: expiresInDays, maxUses: maxUses)
            } label: {
                Text("Создать код")
                    .font(font: .bold, size: 15)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var expiresPicker: some View {
        HStack {
            Text("Срок")
                .font(font: .semiBold, size: 14)
                .secondaryTextStyle()
            Spacer()
            Menu {
                Button("1 день") { expiresInDays = 1 }
                Button("7 дней") { expiresInDays = 7 }
                Button("30 дней") { expiresInDays = 30 }
                Button("Без срока") { expiresInDays = nil }
            } label: {
                Text(expiresLabel)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .appGlass(in: Capsule())
            }
        }
    }

    private var usesPicker: some View {
        HStack {
            Text("Лимит")
                .font(font: .semiBold, size: 14)
                .secondaryTextStyle()
            Spacer()
            Menu {
                Button("1 раз") { maxUses = 1 }
                Button("5 раз") { maxUses = 5 }
                Button("25 раз") { maxUses = 25 }
                Button("Без лимита") { maxUses = nil }
            } label: {
                Text(usesLabel)
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .appGlass(in: Capsule())
            }
        }
    }

    private func inviteRow(_ invite: OrganizationInvite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(invite.code)
                    .font(font: .bold, size: 20)
                    .foregroundStyle(.white.opacity(invite.isActive ? 0.95 : 0.45))
                Spacer()
                if invite.isActive {
                    Button {
                        UIPasteboard.general.string = invite.code
                        AppHaptics.impact(.light)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 34, height: 34)
                            .appGlass(in: Circle())
                    }
                    .buttonStyle(.pressable)
                    Button {
                        AppHaptics.warning()
                        presenter.revokeInvite(invite)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .appGlass(in: Circle())
                    }
                    .buttonStyle(.pressable)
                } else {
                    Text("отозван")
                        .font(font: .semiBold, size: 12)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .appGlass(in: Capsule())
                }
            }
            HStack(spacing: 8) {
                if let exp = invite.expiresAt {
                    metaBadge(text: "до " + exp.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day(.twoDigits).month(.twoDigits)))
                } else {
                    metaBadge(text: "без срока")
                }
                if let max = invite.maxUses {
                    metaBadge(text: "\(invite.usedCount)/\(max)")
                } else {
                    metaBadge(text: "\(invite.usedCount) исп.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metaBadge(text: String) -> some View {
        Text(text)
            .font(font: .semiBold, size: 11)
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .appGlass(in: Capsule())
    }

    private var emptyState: some View {
        Text("Приглашений ещё нет. Создайте код и поделитесь с новым участником.")
            .font(font: .semiBold, size: 13)
            .secondaryTextStyle()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var expiresLabel: String {
        switch expiresInDays {
        case .none: return "без срока"
        case .some(1): return "1 день"
        case .some(let n): return "\(n) дн."
        }
    }

    private var usesLabel: String {
        switch maxUses {
        case .none: return "без лимита"
        case .some(1): return "1 раз"
        case .some(let n): return "\(n) раз"
        }
    }
}

// MARK: - EventsSheet

private struct EventsSheet: View {

    @Bindable var presenter: OrganizationPresenter
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var startsAt: Date = .now
    @State private var hasStartsAt: Bool = false

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if presenter.summary?.role.canManageMembers ?? false {
                        createCard
                    }
                    if presenter.isLoadingEvents && presenter.events.isEmpty {
                        skeletonList
                    } else if presenter.events.isEmpty {
                        emptyState
                    } else {
                        ForEach(presenter.events) { event in
                            eventRow(event)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var skeletonList: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                eventRow(Self.skeletonEvent)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private static let skeletonEvent = OrgEvent(
        id: UUID(),
        organizationID: UUID(),
        name: "Placeholder event name",
        description: "Placeholder description of the event",
        startsAt: Date(),
        createdByID: UUID(),
        createdAt: Date(),
        updatedAt: Date()
    )

    private var header: some View {
        HStack {
            Text("Мероприятия")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer()
            Button("Готово") { presenter.dismissEventsSheet() }
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 15)
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новое мероприятие")
                .font(font: .bold, size: 16)
                .defaultTextStyle()
            GlassTextField(placeholder: "Название", text: $name)
            GlassTextField(placeholder: "Описание (необязательно)", text: $description)
            Toggle(isOn: $hasStartsAt) {
                Text("Задать дату")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .tint(.white)
            if hasStartsAt {
                DatePicker("Когда", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Button {
                AppHaptics.impact(.medium)
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                presenter.createEvent(
                    name: trimmed,
                    description: description,
                    startsAt: hasStartsAt ? startsAt : nil
                )
                name = ""
                description = ""
                hasStartsAt = false
            } label: {
                Text("Создать")
                    .font(font: .bold, size: 15)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func eventRow(_ event: OrgEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .appGlass(in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(font: .bold, size: 15)
                    .defaultTextStyle()
                    .lineLimit(2)
                if let starts = event.startsAt {
                    Text(formatted(starts))
                        .font(font: .semiBold, size: 12)
                        .secondaryTextStyle()
                }
                if !event.description.isEmpty {
                    Text(event.description)
                        .font(font: .regular, size: 12)
                        .secondaryTextStyle()
                        .lineLimit(3)
                }
            }
            Spacer()
            if presenter.summary?.role.canManageMembers ?? false {
                Button {
                    AppHaptics.warning()
                    presenter.deleteEvent(event)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        Text("Мероприятий пока нет.")
            .font(font: .semiBold, size: 13)
            .secondaryTextStyle()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day(.twoDigits).month(.twoDigits).year(.twoDigits).hour().minute())
    }
}

// MARK: - CategoriesSheet

private struct CategoriesSheet: View {

    @Bindable var presenter: OrganizationPresenter
    @State private var name: String = ""

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if presenter.summary?.role.canManageMembers ?? false {
                        createCard
                    }
                    if presenter.isLoadingCategories && presenter.categories.isEmpty {
                        skeletonList
                    } else if presenter.categories.isEmpty {
                        emptyState
                    } else {
                        ForEach(presenter.categories) { category in
                            categoryRow(category)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var skeletonList: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { idx in
                categoryRow(OrgCategory(
                    id: UUID(),
                    organizationID: UUID(),
                    name: "Placeholder name",
                    createdByID: UUID(),
                    createdAt: Date()
                ))
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack {
            Text("Категории")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer()
            Button("Готово") { presenter.dismissCategoriesSheet() }
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 15)
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новая категория")
                .font(font: .bold, size: 16)
                .defaultTextStyle()
            GlassTextField(placeholder: "Название", text: $name)
            Button {
                AppHaptics.impact(.medium)
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                presenter.createCategory(name: trimmed)
                name = ""
            } label: {
                Text("Добавить")
                    .font(font: .bold, size: 15)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func categoryRow(_ category: OrgCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .appGlass(in: Circle())
            Text(category.name)
                .font(font: .bold, size: 15)
                .defaultTextStyle()
                .lineLimit(1)
            Spacer()
            if presenter.summary?.role.canManageMembers ?? false {
                Button {
                    AppHaptics.warning()
                    presenter.deleteCategory(category)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        Text("Пока нет ни одной категории.")
            .font(font: .semiBold, size: 13)
            .secondaryTextStyle()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ActivitySheet

private struct ActivitySheet: View {

    @Bindable var presenter: OrganizationPresenter

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if presenter.isLoadingActivity && presenter.activityEntries.isEmpty {
                        skeletonList
                    } else if presenter.activityEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(presenter.activityEntries) { entry in
                            entryRow(entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var skeletonList: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                entryRow(Self.skeletonEntry)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private static let skeletonEntry = ActivityEntry(
        id: UUID(),
        organizationID: UUID(),
        actorUserID: UUID(),
        actorDisplayName: "Placeholder user",
        kind: "item_created",
        targetType: "item",
        targetID: nil,
        summary: "Placeholder activity summary line",
        createdAt: Date()
    )

    private var header: some View {
        HStack {
            Text("Журнал")
                .font(font: .bold, size: 22)
                .defaultTextStyle()
            Spacer()
            Button("Готово") { presenter.dismissActivitySheet() }
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .semiBold, size: 15)
        }
    }

    private func entryRow(_ entry: ActivityEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: entry.kind))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .appGlass(in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(actorLine(entry))
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(entry.summary.isEmpty ? localizedKind(entry.kind) : entry.summary)
                    .font(font: .bold, size: 14)
                    .defaultTextStyle()
                    .lineLimit(3)
                Text(formatted(entry.createdAt))
                    .font(font: .semiBold, size: 11)
                    .secondaryTextStyle()
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        Text("Пока ничего не происходило.")
            .font(font: .semiBold, size: 13)
            .secondaryTextStyle()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func actorLine(_ entry: ActivityEntry) -> String {
        let name = entry.actorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        return "user • " + entry.actorUserID.uuidString.prefix(8).lowercased()
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "item.created": return "plus.square"
        case "item.updated": return "pencil"
        case "item.archived": return "archivebox"
        case "item.deleted": return "trash"
        case "member.added": return "person.badge.plus"
        case "member.removed": return "person.badge.minus"
        case "member.role_changed": return "person.2"
        case "member.ownership_transferred": return "crown"
        case "event.created", "event.updated", "event.deleted": return "calendar"
        case "category.created", "category.deleted": return "tag"
        case "organization.updated": return "building.2"
        default: return "circle.dashed"
        }
    }

    private func localizedKind(_ kind: String) -> String {
        switch kind {
        case "item.created": return "Добавлена позиция"
        case "item.updated": return "Изменена позиция"
        case "item.archived": return "Списана позиция"
        case "item.deleted": return "Удалена позиция"
        case "member.added": return "Присоединился участник"
        case "member.removed": return "Удалён участник"
        case "member.role_changed": return "Изменена роль"
        case "member.ownership_transferred": return "Передано владение"
        case "event.created": return "Создано мероприятие"
        case "event.updated": return "Изменено мероприятие"
        case "event.deleted": return "Удалено мероприятие"
        case "category.created": return "Добавлена категория"
        case "category.deleted": return "Удалена категория"
        case "organization.updated": return "Изменены данные организации"
        default: return kind
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day(.twoDigits).month(.twoDigits).year(.twoDigits).hour().minute())
    }
}

#Preview {
    let coordinator = AppCoordinator()
    OrganizationAssembly.assemble(appCoordinator: coordinator)
}
