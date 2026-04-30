//
//  AppEnvironment.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum AppEnvironment {

    private static let backendBaseURLPlistKey = "BackendBaseURL"
    private static let backendURLProcessEnvKey = "BACKEND_URL"

    static var backendBaseURL: URL {
        resolveBackendBaseURL()
    }

    private static func resolveBackendBaseURL() -> URL {
        if let raw = ProcessInfo.processInfo.environment[backendURLProcessEnvKey],
           let url = normalizedBackendURL(from: raw) {
            return url
        }

        if let raw = Bundle.main.object(forInfoDictionaryKey: backendBaseURLPlistKey) as? String,
           let url = normalizedBackendURL(from: raw) {
            return url
        }

        guard let url = URL(string: "http://127.0.0.1:8080") else {
            fatalError("Invalid backend base URL")
        }
        return url
    }

    private static func normalizedBackendURL(from raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") {
            s.removeLast()
        }
        guard let url = URL(string: s) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}
