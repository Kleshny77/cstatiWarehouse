//
//  OfflineCacheStoreProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol OfflineCacheStoreProtocol: AnyObject {
    func payload(forKey key: String) async -> Data?
    func save(payload: Data, forKey key: String) async throws
}
