//
// activity.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package domain

import (
	"time"

	"github.com/google/uuid"
)

// ActivityKind описывает тип действия в журнале.
// Держим строковые константы, чтобы лог оставался читаемым в БД и стабильным для клиента.
type ActivityKind string

const (
	ActivityItemCreated          ActivityKind = "item.created"
	ActivityItemUpdated          ActivityKind = "item.updated"
	ActivityItemArchived         ActivityKind = "item.archived"
	ActivityItemDeleted          ActivityKind = "item.deleted"
	ActivityMemberAdded          ActivityKind = "member.added"
	ActivityMemberRemoved        ActivityKind = "member.removed"
	ActivityMemberRoleChanged    ActivityKind = "member.role_changed"
	ActivityOwnershipTransferred ActivityKind = "member.ownership_transferred"
	ActivityEventCreated         ActivityKind = "event.created"
	ActivityEventUpdated         ActivityKind = "event.updated"
	ActivityEventDeleted         ActivityKind = "event.deleted"
	ActivityCategoryCreated      ActivityKind = "category.created"
	ActivityCategoryDeleted      ActivityKind = "category.deleted"
	ActivityOrganizationUpdated  ActivityKind = "organization.updated"
)

// ActivityEntry — одна строка журнала действий в организации.
// Summary — человекочитаемое описание, TargetID — опциональная ссылка на затронутый объект.
type ActivityEntry struct {
	ID             uuid.UUID
	OrganizationID uuid.UUID
	ActorUserID    uuid.UUID
	// ActorDisplayName — только для чтения списка (JOIN с users), в Append не заполняется.
	ActorDisplayName string
	Kind             ActivityKind
	TargetType       string
	TargetID         *uuid.UUID
	Summary          string
	CreatedAt        time.Time
}
