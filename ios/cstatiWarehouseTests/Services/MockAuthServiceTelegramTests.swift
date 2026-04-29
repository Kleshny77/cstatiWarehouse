//
//  MockAuthServiceTelegramTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Testing
@testable import cstatiWarehouse
import Foundation

@Suite("MockAuthService.loginWithTelegram")
struct MockAuthServiceTelegramTests {
    
    @Test
    func loginWithTelegram_returnsUserFromSampleToken() async {
        let service = MockAuthService()
        let token = MockTelegramAuthService.sampleIdToken
        
        let response = await withCheckedContinuation { continuation in
            service.loginWithTelegram(request: TelegramLoginRequest(idToken: token)) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch response {
        case .success(let loginResponse):
            #expect(loginResponse.user.id == "42")
            #expect(loginResponse.user.name == "Демо Пользователь")
            #expect(loginResponse.user.email == "demo_tg@telegram.local")
            #expect(loginResponse.accessToken == "mock-tg-access")
            #expect(loginResponse.refreshToken == "mock-tg-refresh")
        case .failure(let error):
            Issue.record("expected success, got \(error.message)")
        }
    }
    
    @Test
    func loginWithTelegram_failsForGarbageToken() async {
        let service = MockAuthService()
        
        let response = await withCheckedContinuation { continuation in
            service.loginWithTelegram(request: TelegramLoginRequest(idToken: "not-a-jwt")) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch response {
        case .success:
            Issue.record("expected failure for malformed token")
        case .failure(let error):
            #expect(error.message.contains("id_token"))
        }
    }
    
    @Test
    func loginWithTelegram_fallsBackToUsernameWhenNameMissing() async {
        let payload = """
        {"sub":"99","preferred_username":"only_username"}
        """
        let token = makeToken(payload: payload)
        let service = MockAuthService()
        
        let response = await withCheckedContinuation { continuation in
            service.loginWithTelegram(request: TelegramLoginRequest(idToken: token)) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch response {
        case .success(let loginResponse):
            #expect(loginResponse.user.name == "only_username")
            #expect(loginResponse.user.email == "only_username@telegram.local")
        case .failure(let error):
            Issue.record("expected success, got \(error.message)")
        }
    }
    
    
    private func makeToken(payload: String) -> String {
        let header = base64url("{\"alg\":\"none\",\"typ\":\"JWT\"}")
        return "\(header).\(base64url(payload))."
    }
    
    private func base64url(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
