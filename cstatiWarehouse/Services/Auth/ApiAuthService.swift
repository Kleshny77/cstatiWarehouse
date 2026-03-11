//
//  ApiAuthService.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

/// Подключить когда бекенд на Go будет готов.
/// Заменить baseURL, реализовать URLSession запросы к POST /auth/login, POST /auth/register.
/// Ответы бекенда маппить в LoginResponse/RegisterResponse; ошибки (401, 409, 422) — в AuthError.
final class ApiAuthService: AuthServiceProtocol {
  private let baseURL: URL
  private let session: URLSession
  
  init(baseURL: URL = URL(string: "https://api.example.com")!, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }
  
  func login(request: LoginRequest, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
    // TODO: POST baseURL/auth/login, body: { "email": request.email, "password": request.password }
    // 200 -> decode LoginResponse, completion(.success(...))
    // 401 -> completion(.failure(.invalidCredentials))
    // 4xx/5xx -> completion(.failure(.serverError(message)))
    completion(.failure(.serverError("Бекенд ещё не подключён")))
  }
  
  func register(request: RegisterRequest, completion: @escaping (Result<RegisterResponse, AuthError>) -> Void) {
    // TODO: POST baseURL/auth/register, body: { "name", "email", "password" }
    // 201 -> decode RegisterResponse, completion(.success(...))
    // 409 -> completion(.failure(.emailAlreadyTaken))
    // 422 -> completion(.failure(.validationError(message)))
    completion(.failure(.serverError("Бекенд ещё не подключён")))
  }
}
