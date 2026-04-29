package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"

	ws "github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/websocket"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// TODO: В продакшене проверять origin
		return true
	},
}

type WebSocketHandler struct {
	hub *ws.Hub
}

func NewWebSocketHandler(hub *ws.Hub) *WebSocketHandler {
	return &WebSocketHandler{hub: hub}
}

// ServeWS обрабатывает WebSocket подключения
func (h *WebSocketHandler) ServeWS(w http.ResponseWriter, r *http.Request) {
	// Проверка авторизации
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	// Получение organization_id из query параметра
	orgIDStr := r.URL.Query().Get("organization_id")
	if orgIDStr == "" {
		writeError(w, r, domain.NewValidationError("organization_id is required"))
		return
	}

	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid organization_id"))
		return
	}

	// Upgrade HTTP соединения до WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("websocket upgrade failed", "err", err)
		return
	}

	// Создание клиента
	client := ws.NewClient(h.hub, conn, userID, orgID)
	h.hub.Register(client)

	// Запуск горутин для чтения и записи
	go client.WritePump()
	go client.ReadPump()
}
