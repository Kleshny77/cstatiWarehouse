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
