// Package websocket provides WebSocket support for real-time updates.
package websocket

import (
	"log/slog"
	"sync"

	"github.com/google/uuid"
)

// Message типы для WebSocket событий
const (
	MessageTypeItemCreated  = "item.created"
	MessageTypeItemUpdated  = "item.updated"
	MessageTypeItemArchived = "item.archived"
	MessageTypeItemDeleted  = "item.deleted"
)

// Message представляет WebSocket сообщение
type Message struct {
	Type           string      `json:"type"`
	OrganizationID uuid.UUID   `json:"organization_id"`
	Data           interface{} `json:"data"`
}

// Hub управляет WebSocket подключениями и рассылкой сообщений
type Hub struct {
	// Зарегистрированные клиенты по организациям
	clients map[uuid.UUID]map[*Client]bool

	// Канал для регистрации клиентов
	register chan *Client

	// Канал для отмены регистрации клиентов
	unregister chan *Client

	// Канал для broadcast сообщений
	broadcast chan Message

	mu sync.RWMutex
}

// NewHub создаёт новый Hub
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan Message, 256),
	}
}

// Run запускает Hub (должен вызываться в отдельной горутине)
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if h.clients[client.organizationID] == nil {
				h.clients[client.organizationID] = make(map[*Client]bool)
			}
			h.clients[client.organizationID][client] = true
			h.mu.Unlock()
			slog.Info("websocket client registered",
				"org_id", client.organizationID,
				"user_id", client.userID,
			)

		case client := <-h.unregister:
			h.mu.Lock()
			if clients, ok := h.clients[client.organizationID]; ok {
				if _, ok := clients[client]; ok {
					delete(clients, client)
					close(client.send)
					if len(clients) == 0 {
						delete(h.clients, client.organizationID)
					}
				}
			}
			h.mu.Unlock()
			slog.Info("websocket client unregistered",
				"org_id", client.organizationID,
				"user_id", client.userID,
			)

		case message := <-h.broadcast:
			h.mu.RLock()
			clients := h.clients[message.OrganizationID]
			h.mu.RUnlock()

			for client := range clients {
				select {
				case client.send <- message:
				default:
					// Канал переполнен - отключаем клиента
					h.mu.Lock()
					close(client.send)
					delete(h.clients[message.OrganizationID], client)
					h.mu.Unlock()
				}
			}
		}
	}
}

// Broadcast отправляет сообщение всем клиентам организации
func (h *Hub) Broadcast(msg Message) {
	h.broadcast <- msg
}

// Register регистрирует клиента в Hub
func (h *Hub) Register(client *Client) {
	h.register <- client
}

// Unregister отменяет регистрацию клиента
func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}

// ClientCount возвращает количество подключённых клиентов для организации
func (h *Hub) ClientCount(orgID uuid.UUID) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients[orgID])
}
