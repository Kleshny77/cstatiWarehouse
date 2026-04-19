//
// ApiUploadsService.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation
import UIKit

/// Реализация UploadsServiceProtocol поверх POST /uploads (multipart/form-data).
final class ApiUploadsService: UploadsServiceProtocol {

    // MARK: Properties

    private let client: APIClient

    // MARK: Lifecycle

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Public Methods

    func uploadImage(_ image: UIImage, completion: @escaping (Result<URL, UploadsError>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            completion(.failure(.invalidImage))
            return
        }

        let filename = "image_\(UUID().uuidString).jpg"
        client.upload(
            path: "/uploads",
            fieldName: "file",
            filename: filename,
            mimeType: "image/jpeg",
            data: data
        ) { (result: Result<UploadResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let url = URL(string: dto.url) {
                    completion(.success(url))
                } else {
                    completion(.failure(.serverError("Некорректный URL")))
                }
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    // MARK: Private Methods

    private static func mapError(_ error: APIError) -> UploadsError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, _, let message):
            return .serverError(message ?? "Ошибка сервера (\(status))")
        }
    }
}

// MARK: - DTOs

private struct UploadResponseDTO: Decodable {
    let url: String
}
