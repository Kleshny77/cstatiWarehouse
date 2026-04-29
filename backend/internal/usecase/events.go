//
// events.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package usecase

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type EventsUseCase struct {
	events   EventRepository
	members  OrganizationMemberRepository
	activity ActivityRepository
	clock    Clock
}

func NewEventsUseCase(
	events EventRepository,
	members OrganizationMemberRepository,
	activity ActivityRepository,
	clock Clock,
) *EventsUseCase {
	return &EventsUseCase{events: events, members: members, activity: activity, clock: clock}
}

type CreateEventInput struct {
	UserID         uuid.UUID
	OrganizationID uuid.UUID
	Name           string
	Description    string
	StartsAt       *time.Time
}

func (uc *EventsUseCase) Create(ctx context.Context, in CreateEventInput) (*domain.Event, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("event name must not be empty")
	}
	if err := uc.requireManager(ctx, in.UserID, in.OrganizationID); err != nil {
		return nil, err
	}

	now := uc.clock.Now()
	e := &domain.Event{
		ID:             uuid.New(),
		OrganizationID: in.OrganizationID,
		CreatedByID:    in.UserID,
		Name:           name,
		Description:    strings.TrimSpace(in.Description),
		StartsAt:       in.StartsAt,
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	if err := uc.events.Create(ctx, e); err != nil {
		return nil, err
	}
	uc.logActivity(ctx, in.OrganizationID, in.UserID, domain.ActivityEventCreated, "event", &e.ID, "создано мероприятие «"+e.Name+"»")
	return e, nil
}

type UpdateEventInput struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	Name        string
	Description string
	StartsAt    *time.Time
}

func (uc *EventsUseCase) Update(ctx context.Context, in UpdateEventInput) (*domain.Event, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("event name must not be empty")
	}

	event, err := uc.events.FindByID(ctx, in.ID)
	if err != nil {
		return nil, err
	}
	if err := uc.requireManager(ctx, in.UserID, event.OrganizationID); err != nil {
		return nil, err
	}

	event.Name = name
	event.Description = strings.TrimSpace(in.Description)
	event.StartsAt = in.StartsAt
	event.UpdatedAt = uc.clock.Now()
	if err := uc.events.Update(ctx, event); err != nil {
		return nil, err
	}
	uc.logActivity(ctx, event.OrganizationID, in.UserID, domain.ActivityEventUpdated, "event", &event.ID, "обновлено мероприятие «"+event.Name+"»")
	return event, nil
}

func (uc *EventsUseCase) Delete(ctx context.Context, userID, eventID uuid.UUID) error {
	event, err := uc.events.FindByID(ctx, eventID)
	if err != nil {
		return err
	}
	if err := uc.requireManager(ctx, userID, event.OrganizationID); err != nil {
		return err
	}
	if err := uc.events.Delete(ctx, eventID); err != nil {
		return err
	}
	uc.logActivity(ctx, event.OrganizationID, userID, domain.ActivityEventDeleted, "event", &event.ID, "удалено мероприятие «"+event.Name+"»")
	return nil
}

func (uc *EventsUseCase) List(ctx context.Context, userID, orgID uuid.UUID) ([]domain.Event, error) {
	if _, err := uc.findRole(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.events.ListByOrganization(ctx, orgID)
}

func (uc *EventsUseCase) FindAccessibleEvent(ctx context.Context, userID, eventID uuid.UUID) (*domain.Event, error) {
	event, err := uc.events.FindByID(ctx, eventID)
	if err != nil {
		return nil, err
	}
	if _, err := uc.findRole(ctx, userID, event.OrganizationID); err != nil {
		return nil, err
	}
	return event, nil
}

// MARK: private helpers

func (uc *EventsUseCase) findRole(ctx context.Context, userID, orgID uuid.UUID) (domain.OrgRole, error) {
	role, err := uc.members.FindRole(ctx, orgID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return "", domain.ErrForbidden
		}
		return "", err
	}
	return role, nil
}

func (uc *EventsUseCase) requireManager(ctx context.Context, userID, orgID uuid.UUID) error {
	role, err := uc.findRole(ctx, userID, orgID)
	if err != nil {
		return err
	}
	if role != domain.OrgRoleOwner && role != domain.OrgRoleAdmin {
		return domain.ErrForbidden
	}
	return nil
}

func (uc *EventsUseCase) logActivity(ctx context.Context, orgID, userID uuid.UUID, kind domain.ActivityKind, targetType string, targetID *uuid.UUID, summary string) {
	if uc.activity == nil {
		return
	}
	_ = uc.activity.Append(ctx, &domain.ActivityEntry{
		ID:             uuid.New(),
		OrganizationID: orgID,
		ActorUserID:    userID,
		Kind:           kind,
		TargetType:     targetType,
		TargetID:       targetID,
		Summary:        summary,
		CreatedAt:      uc.clock.Now(),
	})
}
