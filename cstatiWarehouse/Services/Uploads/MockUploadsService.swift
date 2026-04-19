//
// MockUploadsService.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation
import UIKit

final class MockUploadsService: UploadsServiceProtocol {
    func uploadImage(_ image: UIImage, completion: @escaping (Result<URL, UploadsError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let fakeURL = URL(string: "https://example.com/uploads/\(UUID().uuidString).jpg")!
            completion(.success(fakeURL))
        }
    }
}
