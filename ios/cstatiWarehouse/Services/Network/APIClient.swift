//
//  APIClient.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Внутренние ошибки `APIClient`, заворачиваемые в `APIError.decoding`.
enum APIClientError: Error {
    /// Сервер вернул пустое тело, но ожидаемый `Response` — не `EmptyResponse`.
    case emptyResponseTypeMismatch
}

final class APIClient {

    private let session: URLSession
    private let sessionStorage: UserSessionStorageProtocol
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let refreshQueue = DispatchQueue(label: "cstatiWarehouse.APIClient.refresh")
    private let refreshLock = NSLock()
    private var isRefreshing = false
    private var refreshCompletionHandlers: [(Result<Void, APIError>) -> Void] = []


    init(
        session: URLSession = APIClient.makeDefaultSession(),
        sessionStorage: UserSessionStorageProtocol
    ) {
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

    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }

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
                    if let empty = EmptyResponse() as? Response {
                        Self.completeOnMain(completion, .success(empty))
                    } else {
                        Self.completeOnMain(
                            completion,
                            .failure(.decoding(underlying: APIClientError.emptyResponseTypeMismatch))
                        )
                    }
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

    private let maxTransportRetries = 2

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

        func runTransportAttempt(attempt: Int) {
            session.dataTask(with: urlRequest) { [weak self] data, response, error in
                guard let self else { return }
                if let error = error {
                    if attempt < self.maxTransportRetries, Self.shouldRetryTransportError(error) {
                        let delay = 0.35 * pow(2.0, Double(attempt))
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            runTransportAttempt(attempt: attempt + 1)
                        }
                        return
                    }
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
                    message: parsed?.message,
                    responseBody: payload
                )))
            }.resume()
        }

        runTransportAttempt(attempt: 0)
    }

    private static func shouldRetryTransportError(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        switch ns.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorNotConnectedToInternet:
            return true
        default:
            return false
        }
    }

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

            self.refreshLock.lock()
            if self.isRefreshing {
                self.refreshCompletionHandlers.append { result in
                    switch result {
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
                        originalCompletion(.failure(.unauthorized))
                    }
                }
                self.refreshLock.unlock()
                return
            }
            
            self.isRefreshing = true
            self.refreshLock.unlock()

            self.refreshTokensSync(refreshToken: refresh) { refreshResult in
                self.refreshLock.lock()
                let handlers = self.refreshCompletionHandlers
                self.refreshCompletionHandlers.removeAll()
                self.isRefreshing = false
                self.refreshLock.unlock()
                
                for handler in handlers {
                    handler(refreshResult)
                }
                
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

    private func refreshTokensSync(
        refreshToken: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, APIError> = .failure(.unauthorized)
        let resultLock = NSLock()

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
            let computed: Result<Void, APIError>
            switch raw {
            case .success(let data):
                do {
                    let dto = try self.decoder.decode(AuthTokensDTO.self, from: data)
                    self.sessionStorage.updateTokens(
                        accessToken: dto.accessToken,
                        refreshToken: dto.refreshToken
                    )
                    computed = .success(())
                } catch {
                    computed = .failure(.decoding(underlying: error))
                }
            case .failure(let err):
                computed = .failure(err)
            }
            resultLock.lock()
            result = computed
            resultLock.unlock()
        }

        // Подстраховка от дедлока: URLSession уже имеет свой таймаут
        // (по умолчанию 60 секунд), но если по какой-то причине callback
        // не будет вызван — этот таймаут не даст зависнуть синхронному вызову.
        let waitDeadline = DispatchTime.now() + Self.refreshSemaphoreTimeout
        if semaphore.wait(timeout: waitDeadline) == .timedOut {
            let timeoutError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: [NSLocalizedDescriptionKey: "Token refresh timed out"]
            )
            resultLock.lock()
            result = .failure(.transport(underlying: timeoutError))
            resultLock.unlock()
        }
        resultLock.lock()
        let finalResult = result
        resultLock.unlock()
        completion(finalResult)
    }

    private static let refreshSemaphoreTimeout: DispatchTimeInterval = .seconds(30)

    private func makeURLRequest(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: AppEnvironment.backendBaseURL.appendingPathComponent(path),
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

    internal static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    internal static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}


struct EmptyResponse: Decodable {}

private struct AnyEncodable: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}


private struct RefreshRequestDTO: Encodable {
    let refreshToken: String
}

private struct AuthTokensDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}
