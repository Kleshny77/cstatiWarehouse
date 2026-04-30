//
//  MockTelegramAuthService.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 17.04.2026.
//

import Foundation
@testable import cstatiWarehouse

final class MockTelegramAuthService: TelegramAuthServiceProtocol {

    private let result: Result<TelegramAuthResult, TelegramAuthError>

    init(result: Result<TelegramAuthResult, TelegramAuthError> = .success(
        TelegramAuthResult(idToken: MockTelegramAuthService.sampleIdToken)
    )) {
        self.result = result
    }

    func signIn(completion: @escaping (Result<TelegramAuthResult, TelegramAuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [result] in
            completion(result)
        }
    }

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
