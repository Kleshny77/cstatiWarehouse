//
// UploadsServiceProtocol.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation
import UIKit

enum UploadsError: Error {
    case invalidImage
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .invalidImage:
            return "Не удалось подготовить изображение"
        case .networkError:
            return "Ошибка сети при загрузке фото"
        case .serverError(let text):
            return text.isEmpty ? "Ошибка сервера при загрузке" : text
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        }
    }
}

protocol UploadsServiceProtocol: AnyObject {
    /// Загружает изображение на сервер и возвращает публичный URL.
    func uploadImage(_ image: UIImage, completion: @escaping (Result<URL, UploadsError>) -> Void)
}
