//
//  OAuthAuthProtocols.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

struct GoogleAuthResult {
    let idToken: String
}

enum GoogleAuthError: Error {
    case notConfigured
    case cancelled
    case noViewController
    case sdkError(String)

    var message: String {
        switch self {
        case .notConfigured:
            return "Вход через Google не настроен (CLIENT_ID в Info.plist)."
        case .cancelled:
            return ""
        case .noViewController:
            return "Не удалось показать окно входа."
        case .sdkError(let s):
            return s
        }
    }
}

protocol GoogleAuthServiceProtocol: AnyObject {
    func signIn(completion: @escaping (Result<GoogleAuthResult, GoogleAuthError>) -> Void)
}
