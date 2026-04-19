//
//  GlassConfirmationSheet.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

/// Подтверждающее модальное окно в стиле приложения: liquid glass, заголовок, сообщение и две кнопки.
struct GlassConfirmationSheet: View {

    // MARK: Properties

    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        confirmTitle: String = "Удалить",
        cancelTitle: String = "Отмена",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    // MARK: Lifecycle

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 20) {
                header
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    // MARK: UI Configuration

    private var header: some View {
        VStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.white.opacity(0.95))
                .font(font: .bold, size: 20)
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.white.opacity(0.65))
                .font(font: .semiBold, size: 13)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                onConfirm()
            } label: {
                Text(confirmTitle)
                    .foregroundStyle(isDestructive ? Color.red.opacity(0.95) : .white.opacity(0.95))
                    .font(font: .bold, size: 15)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)

            Button {
                onCancel()
            } label: {
                Text(cancelTitle)
                    .foregroundStyle(.white.opacity(0.75))
                    .font(font: .bold, size: 15)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
    }
}

#Preview {
    Color.blue.sheet(isPresented: .constant(true)) {
        GlassConfirmationSheet(
            title: "Удалить навсегда?",
            message: "«Пиво Heineken 0,5» будет удалено без возможности восстановления и не попадёт в историю.",
            onConfirm: {},
            onCancel: {}
        )
    }
}
