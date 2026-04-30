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

type ActivityEntry struct {
	ID               uuid.UUID
	OrganizationID   uuid.UUID
	ActorUserID      uuid.UUID
	ActorDisplayName string
	Kind             ActivityKind
	TargetType       string
	TargetID         *uuid.UUID
	Summary          string
	CreatedAt        time.Time
}
