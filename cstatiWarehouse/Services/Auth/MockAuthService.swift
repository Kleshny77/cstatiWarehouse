//
//  MockAuthService.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

final class MockAuthService: AuthServiceProtocol {
  func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      completion(.success(LoginResponse(
        token: "mock-token",
        user: UserDTO(id: "1", name: "User", email: request.email)
      )))
    }
  }
  
  func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      completion(.success(RegisterResponse(
        token: "mock-token",
        user: UserDTO(id: "1", name: request.name, email: request.email)
      )))
    }
  }
}
