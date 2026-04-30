package websocket

import (
	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type Broadcaster struct {
	hub *Hub
}

func NewBroadcaster(hub *Hub) *Broadcaster {
	return &Broadcaster{hub: hub}
}

func (b *Broadcaster) BroadcastItemCreated(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemCreated,
		OrganizationID: orgID,
		Data:           domainItemToWire(item),
	})
}

func (b *Broadcaster) BroadcastItemUpdated(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemUpdated,
		OrganizationID: orgID,
		Data:           domainItemToWire(item),
	})
}

func (b *Broadcaster) BroadcastItemArchived(orgID uuid.UUID, item *domain.Item) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeItemArchived,
		OrganizationID: orgID,
		Data:           domainItemToWire(item),
	})
}

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

func (b *Broadcaster) BroadcastCommentCreated(orgID uuid.UUID, comment *domain.ItemComment) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeCommentCreated,
		OrganizationID: orgID,
		Data:           comment,
	})
}

func (b *Broadcaster) BroadcastCommentUpdated(orgID uuid.UUID, comment *domain.ItemComment) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeCommentUpdated,
		OrganizationID: orgID,
		Data:           comment,
	})
}

func (b *Broadcaster) BroadcastCommentDeleted(orgID uuid.UUID, itemID, commentID uuid.UUID) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeCommentDeleted,
		OrganizationID: orgID,
		Data: map[string]string{
			"item_id":    itemID.String(),
			"comment_id": commentID.String(),
		},
	})
}

func (b *Broadcaster) BroadcastReactionAdded(orgID uuid.UUID, reaction *domain.CommentReaction) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReactionAdded,
		OrganizationID: orgID,
		Data:           reaction,
	})
}

func (b *Broadcaster) BroadcastReactionRemoved(
	orgID uuid.UUID,
	commentID, userID uuid.UUID,
	reaction domain.CommentReactionType,
) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReactionRemoved,
		OrganizationID: orgID,
		Data: map[string]string{
			"comment_id": commentID.String(),
			"user_id":    userID.String(),
			"reaction":   string(reaction),
		},
	})
}

func (b *Broadcaster) BroadcastReservationCreated(orgID uuid.UUID, reservation *domain.ItemReservation) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReservationCreated,
		OrganizationID: orgID,
		Data:           reservation,
	})
}

func (b *Broadcaster) BroadcastReservationFulfilled(orgID uuid.UUID, reservation *domain.ItemReservation) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReservationFulfilled,
		OrganizationID: orgID,
		Data:           reservation,
	})
}

func (b *Broadcaster) BroadcastReservationCancelled(orgID uuid.UUID, reservation *domain.ItemReservation) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReservationCancelled,
		OrganizationID: orgID,
		Data:           reservation,
	})
}

func (b *Broadcaster) BroadcastReservationExpired(orgID uuid.UUID, reservation *domain.ItemReservation) {
	if b.hub == nil {
		return
	}
	b.hub.Broadcast(Message{
		Type:           MessageTypeReservationExpired,
		OrganizationID: orgID,
		Data:           reservation,
	})
}
