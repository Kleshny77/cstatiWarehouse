//
//  APIClient.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// HTTP-методы, используемые клиентом.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Низкоуровневый клиент поверх URLSession с поддержкой:
///   - JSON-кодирования/декодирования (ISO8601 даты, snake_case),
///   - Bearer access-токена для аутентифицированных запросов,
///   - автоматического рефреша токенов на 401 и повторной попытки.
///
/// Колбэки всегда возвращаются на main-очереди для безопасной работы с UI.
final class APIClient {

    // MARK: Properties

    private let baseURL: URL
    private let session: URLSession
    private let sessionStorage: UserSessionStorageProtocol
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Сериализует попытки рефреша между конкурентными запросами.
    private let refreshQueue = DispatchQueue(label: "cstatiWarehouse.APIClient.refresh")

    // MARK: Lifecycle

    init(
        baseURL: URL = AppEnvironment.backendBaseURL,
        session: URLSession = .shared,
        sessionStorage: UserSessionStorageProtocol
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sessionStorage = sessionStorage

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = APIClient.iso8601Fractional.date(from: str) {
                return date
            }
            if let date = APIClient.iso8601Basic.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(str)"
            )
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // MARK: Public Methods

    /// Выполняет запрос с декодированием JSON-ответа.
    func request<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true,
        completion: @escaping (Result<Response, APIError>) -> Void
    ) {
        performRequest(
            path: path,
            method: method,
            query: query,
            body: body,
            authenticated: authenticated,
            retryOn401: authenticated
        ) { [decoder] result in
            switch result {
            case .success(let data):
                if Response.self == EmptyResponse.self, data.isEmpty {
                    Self.completeOnMain(completion, .success(EmptyResponse() as! Response))
                    return
                }
                do {
                    let decoded = try decoder.decode(Response.self, from: data)
                    Self.completeOnMain(completion, .success(decoded))
                } catch {
                    Self.completeOnMain(completion, .failure(.decoding(underlying: error)))
                }
            case .failure(let err):
                Self.completeOnMain(completion, .failure(err))
            }
        }
    }

    /// Выполняет multipart/form-data загрузку файла с полем `fieldName`.
    /// Использует тот же pipeline аутентификации/рефреша токена, что и обычные JSON-запросы.
    func upload<Response: Decodable>(
        path: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data,
        completion: @escaping (Result<Response, APIError>) -> Void
    ) {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = Self.makeMultipartBody(
            boundary: boundary,
            fieldName: fieldName,
            filename: filename,
            mimeType: mimeType,
            data: data
        )
        let contentType = "multipart/form-data; boundary=\(boundary)"

        performDataRequest(
            path: path,
            method: .post,
            query: [],
            bodyData: body,
            contentType: contentType,
            authenticated: true,
            retryOn401: true
        ) { [decoder] result in
            switch result {
            case .success(let payload):
                do {
                    let decoded = try decoder.decode(Response.self, from: payload)
                    Self.completeOnMain(completion, .success(decoded))
                } catch {
                    Self.completeOnMain(completion, .failure(.decoding(underlying: error)))
                }
            case .failure(let err):
                Self.completeOnMain(completion, .failure(err))
            }
        }
    }

    /// Выполняет запрос без декодирования тела ответа (204 / 200 без payload).
    func requestVoid(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        performRequest(
            path: path,
            method: method,
            query: query,
            body: body,
            authenticated: authenticated,
            retryOn401: authenticated
        ) { result in
            switch result {
            case .success:
                Self.completeOnMain(completion, .success(()))
            case .failure(let err):
                Self.completeOnMain(completion, .failure(err))
            }
        }
    }

    // MARK: Private Methods

    private func performRequest(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        body: Encodable?,
        authenticated: Bool,
        retryOn401: Bool,
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        let bodyData: Data?
        do {
            bodyData = try body.map { try encoder.encode(AnyEncodable($0)) }
        } catch {
            completion(.failure(.transport(underlying: error)))
            return
        }
        performDataRequest(
            path: path,
            method: method,
            query: query,
            bodyData: bodyData,
            contentType: bodyData != nil ? "application/json" : nil,
            authenticated: authenticated,
            retryOn401: retryOn401,
            completion: completion
        )
    }

    private func performDataRequest(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool,
        retryOn401: Bool,
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        let urlRequest: URLRequest
        do {
            urlRequest = try makeURLRequest(
                path: path,
                method: method,
                query: query,
                bodyData: bodyData,
                contentType: contentType,
                authenticated: authenticated
            )
        } catch let error as APIError {
            completion(.failure(error))
            return
        } catch {
            completion(.failure(.transport(underlying: error)))
            return
        }

        let accessAtSend = sessionStorage.accessToken

        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error = error {
                completion(.failure(.transport(underlying: error)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.transport(underlying: URLError(.badServerResponse))))
                return
            }
            let payload = data ?? Data()

            if (200..<300).contains(http.statusCode) {
                completion(.success(payload))
                return
            }

            if http.statusCode == 401, retryOn401 {
                self.handleUnauthorized(
                    triedAccess: accessAtSend,
                    originalPath: path,
                    originalMethod: method,
                    originalQuery: query,
                    originalBodyData: bodyData,
                    originalContentType: contentType,
                    originalCompletion: completion
                )
                return
            }

            let parsed = try? self.decoder.decode(APIServerErrorBody.self, from: payload)
            completion(.failure(.server(
                status: http.statusCode,
                code: parsed?.error,
                message: parsed?.message
            )))
        }.resume()
    }

    /// Обработка 401: пробуем обновить токены и повторить запрос один раз.
    private func handleUnauthorized(
        triedAccess: String?,
        originalPath: String,
        originalMethod: HTTPMethod,
        originalQuery: [URLQueryItem],
        originalBodyData: Data?,
        originalContentType: String?,
        originalCompletion: @escaping (Result<Data, APIError>) -> Void
    ) {
        refreshQueue.async { [weak self] in
            guard let self else { return }

            // Если другой запрос уже обновил токен — просто пробуем ещё раз.
            if let current = self.sessionStorage.accessToken, current != triedAccess {
                self.performDataRequest(
                    path: originalPath,
                    method: originalMethod,
                    query: originalQuery,
                    bodyData: originalBodyData,
                    contentType: originalContentType,
                    authenticated: true,
                    retryOn401: false,
                    completion: originalCompletion
                )
                return
            }

            guard let refresh = self.sessionStorage.refreshToken else {
                self.sessionStorage.clear()
                originalCompletion(.failure(.unauthorized))
                return
            }

            self.refreshTokensSync(refreshToken: refresh) { refreshResult in
                switch refreshResult {
                case .success:
                    self.performDataRequest(
                        path: originalPath,
                        method: originalMethod,
                        query: originalQuery,
                        bodyData: originalBodyData,
                        contentType: originalContentType,
                        authenticated: true,
                        retryOn401: false,
                        completion: originalCompletion
                    )
                case .failure:
                    self.sessionStorage.clear()
                    originalCompletion(.failure(.unauthorized))
                }
            }
        }
    }

    /// Синхронный по отношению к refreshQueue вызов /auth/refresh.
    /// Использует семафор, чтобы дождаться URLSession-колбэка, оставаясь внутри refreshQueue.
    private func refreshTokensSync(
        refreshToken: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, APIError> = .failure(.unauthorized)

        let body = RefreshRequestDTO(refreshToken: refreshToken)
        performRequest(
            path: "/auth/refresh",
            method: .post,
            query: [],
            body: body,
            authenticated: false,
            retryOn401: false
        ) { [weak self] raw in
            defer { semaphore.signal() }
            guard let self else { return }
            switch raw {
            case .success(let data):
                do {
                    let dto = try self.decoder.decode(AuthTokensDTO.self, from: data)
                    self.sessionStorage.updateTokens(
                        accessToken: dto.accessToken,
                        refreshToken: dto.refreshToken
                    )
                    result = .success(())
                } catch {
                    result = .failure(.decoding(underlying: error))
                }
            case .failure(let err):
                result = .failure(err)
            }
        }

        semaphore.wait()
        completion(result)
    }

    private func makeURLRequest(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.transport(underlying: URLError(.badURL))
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.transport(underlying: URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated {
            guard let access = sessionStorage.accessToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = bodyData
        }

        return request
    }

    private static func makeMultipartBody(
        boundary: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    // MARK: Private Helpers

    private static func completeOnMain<T, E: Error>(
        _ completion: @escaping (Result<T, E>) -> Void,
        _ value: Result<T, E>
    ) {
        if Thread.isMainThread {
            completion(value)
        } else {
            DispatchQueue.main.async { completion(value) }
        }
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

// MARK: - Helper Types

/// Используется в request<Response> когда тело ответа можно игнорировать.
struct EmptyResponse: Decodable {}

/// Type-erased Encodable, чтобы JSONEncoder мог сериализовать произвольные структуры.
private struct AnyEncodable: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - Internal DTOs for /auth/refresh

private struct RefreshRequestDTO: Encodable {
    let refreshToken: String
}

private struct AuthTokensDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}
