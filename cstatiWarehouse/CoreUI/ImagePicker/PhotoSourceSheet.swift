//
// PhotoSourceSheet.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import SwiftUI
import UIKit

/// Состояние выбора источника фото: камера или галерея.
enum PhotoSource: Identifiable {
    case camera
    case photoLibrary

    var id: String {
        switch self {
        case .camera: return "camera"
        case .photoLibrary: return "photoLibrary"
        }
    }

    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera: return .camera
        case .photoLibrary: return .photoLibrary
        }
    }
}

/// Нижний glass-sheet выбора источника фото: «Сделать фото» / «Выбрать из галереи» / (опц.) «Убрать фото».
/// После выбора источника показывает `ImagePicker` через `fullScreenCover`.
struct PhotoSourcePicker: ViewModifier {

    @Binding var isPresented: Bool
    var allowRemoval: Bool = false
    var onPicked: (UIImage) -> Void
    var onRemove: (() -> Void)?

    @State private var activeSource: PhotoSource?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PhotoSourceOptionsView(
                    allowRemoval: allowRemoval,
                    canUseCamera: UIImagePickerController.isSourceTypeAvailable(.camera),
                    onPickCamera: {
                        isPresented = false
                        activeSource = .camera
                    },
                    onPickGallery: {
                        isPresented = false
                        activeSource = .photoLibrary
                    },
                    onRemove: onRemove.map { handler in
                        {
                            isPresented = false
                            handler()
                        }
                    },
                    onCancel: { isPresented = false }
                )
            }
            .fullScreenCover(item: $activeSource) { source in
                ImagePicker(
                    sourceType: source.uiKitSourceType,
                    onPicked: { image in
                        activeSource = nil
                        onPicked(image)
                    },
                    onCancel: {
                        activeSource = nil
                    }
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Нижний glass-sheet «Сделать фото / Выбрать из галереи» и модальный picker после выбора.
    func photoSourcePicker(
        isPresented: Binding<Bool>,
        allowRemoval: Bool = false,
        onPicked: @escaping (UIImage) -> Void,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        modifier(PhotoSourcePicker(
            isPresented: isPresented,
            allowRemoval: allowRemoval,
            onPicked: onPicked,
            onRemove: onRemove
        ))
    }
}

// MARK: - PhotoSourceOptionsView

private struct PhotoSourceOptionsView: View {

    let allowRemoval: Bool
    let canUseCamera: Bool
    let onPickCamera: () -> Void
    let onPickGallery: () -> Void
    let onRemove: (() -> Void)?
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 14) {
                header
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var header: some View {
        Text("Фото профиля")
            .foregroundStyle(.white.opacity(0.95))
            .font(font: .bold, size: 18)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if canUseCamera {
                sourceButton(title: "Сделать фото", systemImage: "camera.fill", action: onPickCamera)
            }
            sourceButton(title: "Выбрать из галереи", systemImage: "photo.on.rectangle", action: onPickGallery)
            if allowRemoval, let onRemove {
                sourceButton(
                    title: "Убрать фото",
                    systemImage: "trash",
                    tint: Color.red.opacity(0.95),
                    action: onRemove
                )
            }
            sourceButton(
                title: "Отмена",
                systemImage: nil,
                tint: .white.opacity(0.75),
                action: onCancel
            )
        }
    }

    private func sourceButton(
        title: String,
        systemImage: String?,
        tint: Color = .white.opacity(0.95),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(font: .bold, size: 15)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .appGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var sheetHeight: CGFloat {
        let header: CGFloat = 46
        let buttonRow: CGFloat = 62
        var count = 2 // gallery + cancel
        if canUseCamera { count += 1 }
        if allowRemoval, onRemove != nil { count += 1 }
        return header + CGFloat(count) * buttonRow + 40
    }
}
