//
//  ItemEditView.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

struct ItemEditView: View {
    @Bindable var presenter: ItemEditPresenter
    
    init(presenter: ItemEditPresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    form
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
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
                    .glassEffect()
                    .clipShape(Circle())
            }
        }
    }
    
    private var form: some View {
        VStack(spacing: 14) {
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
            
            GlassTextField(
                title: "Категория",
                placeholder: "например, напитки",
                text: $presenter.draft.categoryName
            )
            
            quantityField
            expirationField
        }
    }
    
    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Количество")
                .font(font: .semiBold, size: 14)
                .foregroundStyle(.white.opacity(0.8))
            
            HStack {
                Button {
                    if presenter.draft.quantity > 1 {
                        presenter.draft.quantity -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .glassEffect()
                        .clipShape(Circle())
                }
                
                Text("\(presenter.draft.quantity)")
                    .font(font: .bold, size: 22)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                
                Button {
                    presenter.draft.quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .glassEffect()
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
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
            }
            .disabled(presenter.isSaving)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Button {
                presenter.cancelButtonTapped()
            } label: {
                Text("Отмена")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(font: .semiBold, size: 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
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
        warehouseService: MockWarehouseService(),
        onFinish: { _ in }
    )
}
