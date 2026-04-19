//
//  TelegramIDTokenPayloadTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Testing
@testable import cstatiWarehouse
import Foundation

@Suite("TelegramIDTokenPayload")
struct TelegramIDTokenPayloadTests {
    
    @Test
    func decode_parsesFullPayload() {
        let token = makeToken(payload: """
        {"sub":"42","name":"John Doe","preferred_username":"johndoe","phone_number":"+70000000000"}
        """)
        
        let payload = TelegramIDTokenPayload.decode(idToken: token)
        
        #expect(payload?.sub == "42")
        #expect(payload?.name == "John Doe")
        #expect(payload?.preferredUsername == "johndoe")
        #expect(payload?.phoneNumber == "+70000000000")
    }
    
    @Test
    func decode_parsesMinimalPayload() {
        let token = makeToken(payload: #"{"sub":"7"}"#)
        
        let payload = TelegramIDTokenPayload.decode(idToken: token)
        
        #expect(payload?.sub == "7")
        #expect(payload?.name == nil)
        #expect(payload?.preferredUsername == nil)
        #expect(payload?.phoneNumber == nil)
    }
    
    @Test
    func decode_returnsNilForMalformedToken() {
        #expect(TelegramIDTokenPayload.decode(idToken: "garbage") == nil)
        #expect(TelegramIDTokenPayload.decode(idToken: "header.###not-base64###.sig") == nil)
    }
    
    @Test
    func decode_worksOnMockServiceSampleToken() {
        let payload = TelegramIDTokenPayload.decode(idToken: MockTelegramAuthService.sampleIdToken)
        
        #expect(payload?.sub == "42")
        #expect(payload?.name == "Демо Пользователь")
        #expect(payload?.preferredUsername == "demo_tg")
    }
    
    // MARK: Private Methods
    
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
