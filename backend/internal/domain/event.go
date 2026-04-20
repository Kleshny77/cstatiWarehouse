//
// event.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package domain

import (
	"time"

	"github.com/google/uuid"
)

// Event — мероприятие организации. На него можно списывать позиции склада
// (archive_events.event_id). Отсутствие starts_at допустимо: мероприятие может
// быть без явной даты (например, регулярные активности).
type Event struct {
	ID             uuid.UUID
	OrganizationID uuid.UUID
	CreatedByID    uuid.UUID
	Name           string
	Description    string
	StartsAt       *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}
