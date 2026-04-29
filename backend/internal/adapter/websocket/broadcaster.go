package websocket

import (
	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// Broadcaster реализует usecase.WebSocketBroadcaster
type Broadcaster struct {
	hub *Hub
}

// NewBroadcaster создаёт новый Broadcaster
func NewBroadcaster(hub *Hub) *Broadcaster {
	return &Broadcaster{hub: hub}
}

// BroadcastItemCreated отправляет событие создания позиции
func (b *Broadcaster) BroadcastItemCreated(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemCreated,
		OrganizationID: orgID,
		Data:           item,
	})
}

// BroadcastItemUpdated отправляет событие обновления позиции
func (b *Broadcaster) BroadcastItemUpdated(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemUpdated,
		OrganizationID: orgID,
		Data:           item,
	})
}

// BroadcastItemArchived отправляет событие архивации позиции
func (b *Broadcaster) BroadcastItemArchived(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemArchived,
		OrganizationID: orgID,
		Data:           item,
	})
}

// BroadcastItemDeleted отправляет событие удаления позиции
func (b *Broadcaster) BroadcastItemDeleted(orgID uuid.UUID, itemID uuid.UUID) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemDeleted,
		OrganizationID: orgID,
		Data:           map[string]string{"id": itemID.String()},
	})
}
