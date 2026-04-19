//
// RemoteImageView.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import SwiftUI

/// Универсальный компонент для отображения изображения по URL или локального UIImage.
/// На время загрузки показывает placeholder (инициалы/иконку).
struct RemoteImageView<Placeholder: View>: View {
    let url: URL?
    let localImage: UIImage?
    let placeholder: () -> Placeholder

    init(
        url: URL?,
        localImage: UIImage? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.localImage = localImage
        self.placeholder = placeholder
    }

    var body: some View {
        if let localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
        } else if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder()
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder()
                @unknown default:
                    placeholder()
                }
            }
        } else {
            placeholder()
        }
    }
}
