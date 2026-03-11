//
//  AuthServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

enum AuthError: Error {
  case invalidCredentials
  case emailAlreadyTaken
  case validationError(String)
  case networkError(Error?)
  case serverError(String)
  
  var message: String {
    switch self {
    case .invalidCredentials:
      return "Неверный email или пароль"
    case .emailAlreadyTaken:
      return "Этот email уже зарегистрирован"
    case .validationError(let text):
      return text
    case .networkError:
      return "Ошибка сети. Проверьте подключение."
    case .serverError(let text):
      return text.isEmpty ? "Ошибка сервера" : text
    }
  }
}

struct LoginRequest {
  let email: String
  let password: String
}

struct LoginResponse {
  let token: String
  let user: UserDTO
}

struct RegisterRequest {
  let name: String
  let email: String
  let password: String
}

struct RegisterResponse {
  let token: String
  let user: UserDTO
}

struct UserDTO {
  let id: String
  let name: String
  let email: String
}

protocol AuthServiceProtocol: AnyObject {
  func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void)
  func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void)
}
