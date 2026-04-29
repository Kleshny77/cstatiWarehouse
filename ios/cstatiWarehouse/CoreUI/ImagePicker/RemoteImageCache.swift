//
// RemoteImageCache.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import CryptoKit
import UIKit

actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private var memory: [String: UIImage] = [:]
    private let maxMemoryEntries = 120
    private let diskDirectory: URL
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDirectory = caches.appendingPathComponent("cstatiWarehouse.remoteImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache.shared
        session = URLSession(configuration: configuration)
    }

    func uiImage(for url: URL) async -> UIImage? {
        let key = Self.stableKey(for: url)
        if let cached = memory[key] {
            return cached
        }

        let fileURL = diskFileURL(forKey: key)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            insertMemory(key: key, image: image)
            return image
        }

        do {
            let (data, response) = try await session.data(from: url)
            if Task.isCancelled { return nil }
            try Task.checkCancellation()

            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200 ... 299).contains(status) else { return nil }
            guard let image = UIImage(data: data) else { return nil }

            insertMemory(key: key, image: image)
            try? data.write(to: fileURL, options: .atomic)
            return image
        } catch {
            return nil
        }
    }

    private func insertMemory(key: String, image: UIImage) {
        if memory.count >= maxMemoryEntries {
            let dropCount = max(1, memory.count / 2)
            for k in memory.keys.prefix(dropCount) {
                memory.removeValue(forKey: k)
            }
        }
        memory[key] = image
    }

    private func diskFileURL(forKey key: String) -> URL {
        diskDirectory.appendingPathComponent(key).appendingPathExtension("img")
    }

    private static func stableKey(for url: URL) -> String {
        let string = url.absoluteString
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
