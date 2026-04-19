//
//  TelegramLoginAuthService.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import TelegramLogin

final class TelegramLoginAuthService: TelegramAuthServiceProtocol {
    
    // MARK: Public Methods
    
    func signIn(completion: @escaping (Result<TelegramAuthResult, TelegramAuthError>) -> Void) {
        guard TelegramAuthConfig.isConfigured else {
            DispatchQueue.main.async {
                completion(.failure(.notConfigured))
            }
            return
        }
        
        DispatchQueue.main.async {
            TelegramLogin.login { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        completion(.success(TelegramAuthResult(idToken: data.idToken)))
                    case .failure(let error):
                        if let tgError = error as? TelegramLoginError {
                            switch tgError {
                            case .notConfigured:
                                completion(.failure(.notConfigured))
                            case .cancelled:
                                completion(.failure(.cancelled))
                            default:
                                completion(.failure(.underlying(tgError)))
                            }
                        } else {
                            completion(.failure(.underlying(error)))
                        }
                    }
                }
            }
        }
    }
}
