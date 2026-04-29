# WebSocket Real-Time Updates

## Overview

WebSocket support has been implemented to provide real-time updates for warehouse items across all connected clients in an organization.

## Backend Implementation

### Architecture

**Location**: `backend/internal/adapter/websocket/`

**Components**:
1. **Hub** (`hub.go`) - Manages WebSocket connections grouped by organization
2. **Client** (`client.go`) - Represents individual WebSocket connection with ping/pong heartbeat
3. **Broadcaster** (`broadcaster.go`) - Implements `usecase.WebSocketBroadcaster` interface
4. **Handler** (`websocket_handler.go`) - HTTP handler for WebSocket upgrade endpoint

### Message Types

```go
const (
    MessageTypeItemCreated  = "item.created"
    MessageTypeItemUpdated  = "item.updated"
    MessageTypeItemArchived = "item.archived"
    MessageTypeItemDeleted  = "item.deleted"
)
```

### Message Structure

```go
type Message struct {
    Type           string      `json:"type"`
    OrganizationID uuid.UUID   `json:"organization_id"`
    Data           interface{} `json:"data"`
}
```

### Endpoint

**URL**: `GET /ws?organization_id={uuid}`

**Authentication**: Bearer token required in Authorization header

**Query Parameters**:
- `organization_id` (required) - UUID of the organization to subscribe to

### Integration with Use Cases

The `WarehouseUseCase` broadcasts events after successful operations:

```go
// After Create
uc.broadcaster.BroadcastItemCreated(item.OrganizationID, item)

// After Update
uc.broadcaster.BroadcastItemUpdated(item.OrganizationID, item)

// After Archive
uc.broadcaster.BroadcastItemArchived(item.OrganizationID, item)

// After Delete
uc.broadcaster.BroadcastItemDeleted(orgID, id)
```

### Connection Management

- **Heartbeat**: Ping/pong every 54 seconds (60s timeout)
- **Buffer**: 256 messages per client
- **Cleanup**: Automatic disconnection on buffer overflow or connection errors
- **Thread-safe**: Uses `sync.RWMutex` for concurrent access

## iOS Implementation

### Architecture

**Location**: `ios/cstatiWarehouse/Services/WebSocket/`

**Component**: `WebSocketService` - Manages WebSocket connection using `URLSessionWebSocketTask`

### Event Handler Protocol

```swift
protocol WebSocketEventHandler: AnyObject {
    func handleItemCreated(_ item: Item)
    func handleItemUpdated(_ item: Item)
    func handleItemArchived(_ item: Item)
    func handleItemDeleted(itemID: UUID)
}
```

### Usage

```swift
// Initialize (done in AppServices)
let webSocketService = WebSocketService(
    baseURL: apiClient.baseURL,
    tokenStorage: sessionStorage
)

// Connect to organization
webSocketService.connect(organizationID: orgID)

// Set event handler
webSocketService.eventHandler = self

// Disconnect
webSocketService.disconnect()
```

### Message Decoding

Uses the same `ItemDTO` decoder as `ApiWarehouseService` to ensure consistency:

```swift
private func decodeItem(from data: Data) -> Item? {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { ... }
    
    let itemDTO = try decoder.decode(ItemDTO.self, from: data)
    return itemDTO.toItem()
}
```

### Connection Lifecycle

1. **Connect**: Converts HTTP(S) URL to WS(S), adds auth header, subscribes to organization
2. **Receive**: Continuously receives messages in background
3. **Parse**: Decodes JSON and dispatches to event handler on main thread
4. **Disconnect**: Gracefully closes connection

## Integration Points

### Backend

1. **main.go**: Initialize Hub and Broadcaster
```go
wsHub := websocket.NewHub()
go wsHub.Run()
wsBroadcaster := websocket.NewBroadcaster(wsHub)

warehouseUC := usecase.NewWarehouseUseCase(...)
    .WithBroadcaster(wsBroadcaster)
```

2. **router.go**: Add WebSocket endpoint
```go
if deps.WebSocket != nil {
    mux.Handle("GET /ws", auth(http.HandlerFunc(deps.WebSocket.ServeWS)))
}
```

### iOS

1. **AppServices.swift**: Create singleton WebSocketService
```swift
static let webSocketService: WebSocketService = WebSocketService(
    baseURL: apiClient.baseURL,
    tokenStorage: sessionStorage
)
```

2. **MyWarehouseInteractor**: Implement `WebSocketEventHandler` (TODO)
3. **Connect on organization change**: Call `connect(organizationID:)` when active organization changes (TODO)

## Next Steps (iOS Integration)

1. Make `MyWarehouseInteractor` conform to `WebSocketEventHandler`
2. Connect WebSocket when active organization is resolved
3. Handle incoming events:
   - `handleItemCreated`: Add item to local state
   - `handleItemUpdated`: Update item in local state
   - `handleItemArchived`: Update item status
   - `handleItemDeleted`: Remove item from local state
4. Disconnect WebSocket on organization change or app background
5. Add reconnection logic on network recovery

## Testing

### Backend

```bash
# Start server
cd backend && go run ./cmd/server

# Connect with wscat
wscat -c "ws://localhost:8080/ws?organization_id=<uuid>" \
  -H "Authorization: Bearer <token>"

# Trigger events by creating/updating items via REST API
curl -X POST http://localhost:8080/items \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","organization_id":"<uuid>",...}'
```

### iOS

1. Set breakpoint in `WebSocketEventHandler` methods
2. Create/update/delete items from another device
3. Verify events are received and UI updates

## Performance Considerations

- **Scalability**: Hub uses channels for non-blocking broadcast
- **Memory**: Clients are cleaned up automatically on disconnect
- **Network**: Ping/pong keeps connection alive, prevents idle timeout
- **Concurrency**: Thread-safe with RWMutex for read-heavy workloads

## Security

- **Authentication**: JWT token required for WebSocket upgrade
- **Authorization**: Users can only subscribe to organizations they're members of
- **Isolation**: Messages are only sent to clients subscribed to the same organization
- **Rate Limiting**: Inherits from HTTP middleware (auth required)

## Monitoring

Log messages include:
- Client registration/unregistration with org_id and user_id
- Connection errors
- Message parsing errors
- Reconnection attempts (iOS)

## Future Enhancements

1. **Presence**: Track online/offline status of organization members
2. **Typing indicators**: Show when someone is editing an item
3. **Optimistic UI**: Update UI immediately, rollback on conflict
4. **Batch updates**: Group multiple changes into single message
5. **Compression**: Enable WebSocket compression for large payloads
6. **Metrics**: Track connection count, message throughput, latency
