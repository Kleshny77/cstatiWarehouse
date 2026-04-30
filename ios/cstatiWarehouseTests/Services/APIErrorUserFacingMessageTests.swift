//
//  APIErrorUserFacingMessageTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

struct APIErrorUserFacingMessageTests {

    @Test
    func decoding_returnsRussianCopy() {
        let sut = APIError.decoding(underlying: NSError(domain: "x", code: 1))
        #expect(sut.userFacingMessage.contains("разобрать"))
    }

    @Test
    func unauthorized_returnsRussianCopy() {
        let sut = APIError.unauthorized
        #expect(sut.userFacingMessage.contains("Сессия"))
    }

    @Test
    func transport_notConnected_mapsToOfflineCopy() {
        let err = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [:]
        )
        let sut = APIError.transport(underlying: err)
        #expect(sut.userFacingMessage.contains("интернет"))
    }

    @Test
    func server_prefersMessageBody() {
        let sut = APIError.server(status: 500, code: nil, message: "Проблема на стороне сервера", responseBody: Data())
        #expect(sut.userFacingMessage == "Проблема на стороне сервера")
    }

    @Test
    func server_emptyMessage_fallback() {
        let sut = APIError.server(status: 502, code: nil, message: "   ", responseBody: Data())
        #expect(sut.userFacingMessage.contains("Сервер"))
    }
}
