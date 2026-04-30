//
//  WebSocketService.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum WebSocketMessageType: String {
    case itemCreated = "item.created"
    case itemUpdated = "item.updated"
    case itemArchived = "item.archived"
    case itemDeleted = "item.deleted"
}

protocol WebSocketEventHandler: AnyObject {
    func handleItemCreated(_ item: Item)
    func handleItemUpdated(_ item: Item)
    func handleItemArchived(_ item: Item)
    func handleItemDeleted(itemID: UUID)
}

final class WebSocketService {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let baseURL: String
    private let sessionStorage: UserSessionStorageProtocol

    private var isConnected = false
    private var currentOrganizationID: UUID?

    weak var eventHandler: WebSocketEventHandler?

    init(baseURL: String, sessionStorage: UserSessionStorageProtocol) {
        self.baseURL = baseURL
        self.sessionStorage = sessionStorage
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func connect(organizationID: UUID) {
        disconnect() // Disconnect previous connection if any
        
        guard let accessToken = sessionStorage.accessToken else {
            print("[WebSocket] No access token available")
            return
        }
        
        var wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
        wsURL = wsURL.replacingOccurrences(of: "https://", with: "wss://")
        
        guard var urlComponents = URLComponents(string: "\(wsURL)/ws") else {
            print("[WebSocket] Invalid URL")
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "organization_id", value: organizationID.uuidString)
        ]
        
        guard let url = urlComponents.url else {
            print("[WebSocket] Failed to construct URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        currentOrganizationID = organizationID

        print("[WebSocket] Connecting: \(url.absoluteString)")
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        currentOrganizationID = nil
        print("[WebSocket] Disconnected")
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
                
            case .failure(let error):
                print("[WebSocket] Receive error: \(error)")
                self.isConnected = false
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            parseMessage(data)
            
        case .data(let data):
            parseMessage(data)
            
        @unknown default:
            break
        }
    }
    
    private func parseMessage(_ data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                print("[WebSocket] Invalid message format")
                return
            }
            
            guard let messageType = WebSocketMessageType(rawValue: type) else {
                print("[WebSocket] Unknown message type: \(type)")
                return
            }
            
            switch messageType {
            case .itemCreated, .itemUpdated, .itemArchived:
                if let itemData = json["data"],
                   let itemJSON = try? JSONSerialization.data(withJSONObject: itemData),
                   let item = decodeItem(from: itemJSON) {
                    DispatchQueue.main.async {
                        switch messageType {
                        case .itemCreated:
                            self.eventHandler?.handleItemCreated(item)
                        case .itemUpdated:
                            self.eventHandler?.handleItemUpdated(item)
                        case .itemArchived:
                            self.eventHandler?.handleItemArchived(item)
                        default:
                            break
                        }
                    }
                }
                
            case .itemDeleted:
                if let itemData = json["data"] as? [String: String],
                   let idString = itemData["id"],
                   let itemID = UUID(uuidString: idString) {
                    DispatchQueue.main.async {
                        self.eventHandler?.handleItemDeleted(itemID: itemID)
                    }
                }
            }
        } catch {
            print("[WebSocket] Failed to parse message: \(error)")
        }
    }
    
    private func decodeItem(from data: Data) -> Item? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = APIClient.iso8601Fractional.date(from: dateString) {
                return date
            }
            if let date = APIClient.iso8601Basic.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        
        do {
            let itemDTO = try decoder.decode(ItemDTO.self, from: data)
            return itemDTO.toItem()
        } catch {
            print("[WebSocket] Failed to decode item: \(error)")
            return nil
        }
    }
    
    deinit {
        disconnect()
    }
}
