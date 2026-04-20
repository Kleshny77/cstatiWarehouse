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

    /// Ширина основной колонки формы — совпадает с `GlassTextField` (331),
    /// чтобы все поля/карточки выравнивались по одной вертикали.
    private let formWidth: CGFloat = 331

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
                .frame(width: formWidth)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
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
        .frame(width: formWidth)
    }
    
    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            photoField

            GlassTextField(
                title: "Название",
                placeholder: "например, лимонад",
                text: $presenter.draft.name
            )

            GlassTextField(
                title: "Описание",
                placeholder: "необязательно",
                text: $presenter.draft.description
            )

            VStack(alignment: .leading, spacing: 8) {
                GlassTextField(
                    title: "Категория",
                    placeholder: "например, напитки",
                    text: $presenter.draft.categoryName
                )
                categoryChipsRow
            }

            quantityField
            expirationField
        }
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
            .frame(width: formWidth, height: 160)
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
                .frame(width: formWidth, height: 160)
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
    
    @ViewBuilder
    private var categoryChipsRow: some View {
        if !presenter.existingCategories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presenter.existingCategories, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }
    
    private func categoryChip(_ name: String) -> some View {
        let isSelected = presenter.draft.categoryName
            .trimmingCharacters(in: .whitespacesAndNewlines) == name
        return Button {
            presenter.selectCategory(name)
        } label: {
            Text(name)
                .font(font: .semiBold, size: 13)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.clear)
                )
                .appGlass(in: Capsule())
                .appAnimation(AppAnimation.snap, value: isSelected)
        }
        .buttonStyle(.pressable)
    }
    
    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Количество")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 12) {
                Button {
                    if presenter.draft.quantity > 1 {
                        AppHaptics.selection()
                        presenter.draft.quantity -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
                
                Text("\(presenter.draft.quantity)")
                    .font(font: .bold, size: 22)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .appAnimation(AppAnimation.snap, value: presenter.draft.quantity)
                
                Button {
                    AppHaptics.selection()
                    presenter.draft.quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .appGlass(in: Circle())
                }
                .buttonStyle(.pressable)
            }
            .frame(width: formWidth, height: 56)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var expirationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $presenter.draft.hasShelfLife) {
                Text("Есть срок годности")
                    .font(font: .semiBold, size: 14)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .tint(.white.opacity(0.8))
            .frame(width: formWidth)

            if presenter.draft.hasShelfLife {
                DatePicker(
                    "Срок",
                    selection: $presenter.draft.expirationDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(.white)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: formWidth)
                .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
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
                .frame(width: formWidth, height: 50)
                .appAnimation(AppAnimation.snap, value: presenter.isSaving)
            }
            .disabled(presenter.isSaving)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.pressable)

            Button {
                presenter.cancelButtonTapped()
            } label: {
                Text("Отмена")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 14)
                    .frame(width: formWidth, height: 44)
            }
            .buttonStyle(.pressable)
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

#Preview {
    ItemEditAssembly.assemble(
        mode: .create(suggestedCategory: "напитки"),
        organizationID: UUID(),
        warehouseService: MockWarehouseService(),
        onFinish: { _ in }
    )
}
