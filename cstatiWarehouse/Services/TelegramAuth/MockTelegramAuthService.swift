//
//  MockTelegramAuthService.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

final class MockTelegramAuthService: TelegramAuthServiceProtocol {
    
    // MARK: Properties
    
    private let result: Result<TelegramAuthResult, TelegramAuthError>
    
    // MARK: Lifecycle
    
    init(result: Result<TelegramAuthResult, TelegramAuthError> = .success(
        TelegramAuthResult(idToken: MockTelegramAuthService.sampleIdToken)
    )) {
        self.result = result
    }
    
    // MARK: Public Methods
    
    func signIn(completion: @escaping (Result<TelegramAuthResult, TelegramAuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [result] in
            completion(result)
        }
    }
    
    // MARK: Private Methods
    
    /// Подписан «none» (не настоящий JWT, но с валидной base64url-структурой и payload).
    /// Нужен исключительно для локальной разработки — Mock не проверяет подпись.
    static let sampleIdToken: String = {
        let header = "{\"alg\":\"none\",\"typ\":\"JWT\"}"
        let payload = """
        {"iss":"https://oauth.telegram.org","aud":"123456","sub":"42",\
        "name":"Демо Пользователь","preferred_username":"demo_tg",\
        "phone_number":"+70000000000","iat":1700000000,"exp":4102444800}
        """
        return "\(base64url(header)).\(base64url(payload))."
    }()
    
    private static func base64url(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
