//
// category.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package domain

import (
	"time"

	"github.com/google/uuid"
)

type Category struct {
	ID             uuid.UUID
	OrganizationID uuid.UUID
	CreatedByID    uuid.UUID
	Name           string
	CreatedAt      time.Time
}
