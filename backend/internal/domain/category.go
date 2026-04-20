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

// Category — элемент общего справочника категорий организации.
// Имя у позиций по-прежнему хранится строкой в items.category_name;
// Category существует как редактируемый набор подсказок для UI
// и может быть расширен до жёсткой связи "item → category_id" в будущем.
type Category struct {
	ID             uuid.UUID
	OrganizationID uuid.UUID
	CreatedByID    uuid.UUID
	Name           string
	CreatedAt      time.Time
}
