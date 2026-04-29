//
//  GoogleSignInAuthService.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import GoogleSignIn
import UIKit

final class GoogleSignInAuthService: GoogleAuthServiceProtocol {

    func signIn(completion: @escaping (Result<GoogleAuthResult, GoogleAuthError>) -> Void) {
        guard GoogleOAuthConfig.isConfigured else {
            completion(.failure(.notConfigured))
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: GoogleOAuthConfig.clientID)

        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(.failure(.noViewController))
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error {
                let msg = error.localizedDescription.lowercased()
                if msg.contains("cancel") || msg.contains("отмен") || msg.contains("cancell") {
                    completion(.failure(.cancelled))
                    return
                }
                completion(.failure(.sdkError(error.localizedDescription)))
                return
            }
            guard let token = result?.user.idToken?.tokenString else {
                completion(.failure(.sdkError("Нет id_token")))
                return
            }
            completion(.success(GoogleAuthResult(idToken: token)))
        }
    }
}
