//
// RemoteImageView.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import SwiftUI

struct RemoteImageView<Placeholder: View>: View {
    let url: URL?
    let localImage: UIImage?
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

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
            Group {
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder()
                }
            }
            .task(id: url) {
                let image = await RemoteImageCache.shared.uiImage(for: url)
                if Task.isCancelled { return }
                loadedImage = image
            }
        } else {
            placeholder()
        }
    }
}
