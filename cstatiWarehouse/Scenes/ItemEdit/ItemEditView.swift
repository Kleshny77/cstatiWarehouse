//
//  ItemEditView.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct ItemEditView: View {
    @Bindable var presenter: ItemEditPresenter

    @State private var isPhotoSheetPresented: Bool = false
    @State private var newCategoryDraft: String = ""

    init(presenter: ItemEditPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    form
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .photoSourcePicker(
            isPresented: $isPhotoSheetPresented,
            allowRemoval: presenter.draft.pickedImage != nil || presenter.draft.existingImageURL != nil,
            onPicked: { image in
                presenter.draft.pickedImage = image
                presenter.draft.existingImageURL = nil
            },
            onRemove: {
                presenter.draft.pickedImage = nil
                presenter.draft.existingImageURL = nil
            }
        )
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") {
                presenter.errorMessage = nil
            }
        } message: {
            if let error = presenter.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $presenter.isHolderPickerPresented) {
            HolderPickerSheet(
                members: presenter.members,
                selectedID: presenter.draft.holderID,
                onSelect: { member in
                    presenter.selectHolder(member)
                },
                onCancel: {
                    presenter.isHolderPickerPresented = false
                }
            )
        }
        .sheet(isPresented: $presenter.isNewCategorySheetPresented, onDismiss: { newCategoryDraft = "" }) {
            newCategorySheet
        }
    }

    // MARK: UI Configuration

    private var header: some View {
        HStack {
            Text(presenter.screenTitle)
                .font(font: .bold, size: 24)
                .defaultTextStyle()
            Spacer()
            Button {
                presenter.cancelButtonTapped()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .appGlass(in: Circle())
            }
            .buttonStyle(.pressable)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            photoField

            GlassTextField(
                title: "Название",
                placeholder: "например, лимонад",
                text: $presenter.draft.name,
                useFullWidth: true
            )
            .disabled(!presenter.isNameFieldEditable)
            .opacity(presenter.isNameFieldEditable ? 1 : 0.75)

            GlassTextField(
                title: "Описание",
                placeholder: "необязательно",
                text: $presenter.draft.description,
                useFullWidth: true
            )

            categorySection

            if presenter.showsMultiPackToggle {
                Toggle(isOn: $presenter.draft.isMultiPackGroup) {
                    Text("Несколько вариантов одного товара")
                        .font(font: .semiBold, size: 14)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .tint(.white.opacity(0.8))
                .padding(.vertical, 4)
            }

            if !presenter.hidesQuantityStepper {
                quantityField
            } else {
                Text("Остаток, единица учёта и объём упаковки задаются у каждого варианта отдельно.")
                    .font(font: .regular, size: 14)
                    .foregroundStyle(.white.opacity(0.65))
            }

            if presenter.showsMeasureFields {
                measureUnitPicker
            }

            if presenter.showsMeasureFields && presenter.draft.measureUnit == .liter {
                GlassTextField(
                    title: "Литров в одной упаковке",
                    placeholder: "например, 0,7",
                    text: $presenter.draft.volumePerUnitText,
                    useFullWidth: true
                )
            }

            if presenter.showsVariantLabelField {
                GlassTextField(
                    title: "Как отличить",
                    placeholder: "например, 0,7 л или 1 л",
                    text: $presenter.draft.variantLabel,
                    useFullWidth: true
                )
            }

            GlassTextField(
                title: "Адрес",
                placeholder: "например, склад №1",
                text: $presenter.draft.locationAddress,
                useFullWidth: true
            )

            holderField
            expirationField
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Категория")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    AppHaptics.impact(.light)
                    newCategoryDraft = ""
                    presenter.isNewCategorySheetPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Новая")
                            .font(font: .semiBold, size: 13)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .appGlass(in: Capsule())
                }
                .buttonStyle(.pressable)
            }

            if !presenter.draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Выбрано: \(presenter.draft.categoryName)")
                    .font(font: .semiBold, size: 12)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            categoryChipsScroll
        }
    }

    private var categoryChipsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presenter.orgCategories) { cat in
                    GlassChip(title: cat.name, isSelected: isCategorySelected(cat.name)) {
                        presenter.selectCategory(name: cat.name)
                    }
                }
                ForEach(presenter.extraCategoryNames, id: \.self) { name in
                    GlassChip(title: name, isSelected: isCategorySelected(name)) {
                        presenter.selectCategory(name: name)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func isCategorySelected(_ name: String) -> Bool {
        presenter.draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame
    }

    private var newCategorySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(
                title: "Новая категория",
                subtitle: "Будет доступна всем участникам организации",
                onClose: { presenter.isNewCategorySheetPresented = false }
            )

            GlassTextField(
                title: "Название",
                placeholder: "например, напитки",
                text: $newCategoryDraft,
                useFullWidth: true
            )

            HStack(spacing: 10) {
                GlassPillButton("Отмена", role: .secondary) {
                    presenter.isNewCategorySheetPresented = false
                }
                GlassPillButton(
                    "Создать",
                    role: .primary,
                    isEnabled: !newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    presenter.createNewCategory(name: newCategoryDraft)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .presentationDetents([.height(298)])
        .presentationDragIndicator(.visible)
        .presentationBackground(SheetPresentationChrome.organizationManagementGradient)
    }

    private var holderField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Держатель")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                AppHaptics.impact(.light)
                presenter.isHolderPickerPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(holderTitle)
                        .font(font: .semiBold, size: 14)
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(presenter.members.isEmpty)
        }
    }

    private var holderTitle: String {
        if let holder = presenter.currentHolder {
            let name = holder.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty { return name }
            if let email = holder.email, !email.isEmpty { return email }
        }
        return "Выбрать держателя"
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Фото")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                isPhotoSheetPresented = true
            } label: {
                photoPreview
            }
            .buttonStyle(.pressable)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        let hasImage = presenter.draft.pickedImage != nil || presenter.draft.existingImageURL != nil

        if hasImage {
            RemoteImageView(
                url: presenter.draft.existingImageURL,
                localImage: presenter.draft.pickedImage,
                placeholder: { photoPlaceholder }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(10)
            }
        } else {
            photoPlaceholder
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Text("Добавить фото")
                .font(font: .semiBold, size: 13)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var measureUnitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Единица учёта")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))
            Picker("", selection: $presenter.draft.measureUnit) {
                ForEach(ItemMeasureUnit.allCases, id: \.self) { unit in
                    Text(unit.shortTitle).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .tint(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Количество")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .center, spacing: 0) {
                let lower = presenter.quantityLowerBound
                quantityStepButton(
                    systemName: "minus",
                    isEnabled: presenter.draft.quantity > lower
                ) {
                    if presenter.draft.quantity > lower {
                        AppHaptics.selection()
                        presenter.draft.quantity -= 1
                    }
                }

                Text("\(presenter.draft.quantity)")
                    .font(font: .bold, size: 22)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: presenter.draft.quantity)

                quantityStepButton(systemName: "plus", isEnabled: true) {
                    AppHaptics.selection()
                    presenter.draft.quantity += 1
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func quantityStepButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.35))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .appGlass(in: Circle())
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .frame(width: 48, height: 48)
    }

    private var expirationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $presenter.draft.hasShelfLife) {
                Text("Есть срок годности")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .tint(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)

            if presenter.draft.hasShelfLife {
                DrumDatePicker(selection: $presenter.draft.expirationDate)
                    .padding(.horizontal, 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .appAnimation(AppAnimation.smooth, value: presenter.draft.hasShelfLife)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                presenter.saveButtonTapped()
            } label: {
                HStack {
                    if presenter.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(presenter.isSaving ? "Сохранение..." : "Сохранить")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(font: .bold, size: 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .appAnimation(AppAnimation.snap, value: presenter.isSaving)
            }
            .disabled(presenter.isSaving)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.pressable)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                presenter.cancelButtonTapped()
            } label: {
                Text("Отмена")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.pressable)
            .contentShape(Rectangle())
        }
        .padding(.top, 16)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.errorMessage = nil } }
        )
    }
}

// MARK: - HolderPickerSheet

private struct HolderPickerSheet: View {
    let members: [OrganizationMember]
    let selectedID: UUID?
    let onSelect: (OrganizationMember) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if members.isEmpty {
                        emptyState
                    } else {
                        ForEach(members) { member in
                            row(member)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        SheetHeader(title: "Кто держит позицию", onClose: onCancel)
    }

    private func row(_ member: OrganizationMember) -> some View {
        let isSelected = member.userID == selectedID
        return Button {
            AppHaptics.selection()
            onSelect(member)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(member))
                        .font(font: .bold, size: 14)
                        .defaultTextStyle()
                    if let email = member.email, !email.isEmpty {
                        Text(email)
                            .font(font: .semiBold, size: 12)
                            .secondaryTextStyle()
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
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
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        Text("Нет участников для выбора")
            .font(font: .semiBold, size: 13)
            .secondaryTextStyle()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func displayName(_ member: OrganizationMember) -> String {
        let name = member.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        if let email = member.email, !email.isEmpty { return email }
        return "user • " + member.userID.uuidString.prefix(8).lowercased()
    }
}

#Preview {
    ItemEditAssembly.assemble(
        mode: .create(suggestedCategory: "напитки"),
        organizationID: UUID(),
        warehouseService: MockWarehouseService(),
        onFinish: { _ in }
    )
}
