//
// events_test.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func newEventsUC(t *testing.T) (*EventsUseCase, *fakeMemberRepo, *fakeActivityRepo, uuid.UUID, uuid.UUID) {
	t.Helper()
	members := newFakeMemberRepo()
	orgID := uuid.New()
	ownerID := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         ownerID,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("add owner: %v", err)
	}
	events := newFakeEventRepo()
	activity := newFakeActivityRepo()
	clock := newFakeClock(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))
	uc := NewEventsUseCase(events, members, activity, clock)
	return uc, members, activity, ownerID, orgID
}

func TestEventsUseCase_CreateRequiresManager(t *testing.T) {
	uc, members, _, _, orgID := newEventsUC(t)
	stranger := uuid.New()
	if _, err := uc.Create(context.Background(), CreateEventInput{
		UserID:         stranger,
		OrganizationID: orgID,
		Name:           "Конф",
	}); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("expected forbidden, got %v", err)
	}

	member := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         member,
		Role:           domain.OrgRoleMember,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("add member: %v", err)
	}
	if _, err := uc.Create(context.Background(), CreateEventInput{
		UserID:         member,
		OrganizationID: orgID,
		Name:           "Конф",
	}); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("member must be forbidden, got %v", err)
	}
}

func TestEventsUseCase_CreateAndList(t *testing.T) {
	uc, _, activity, ownerID, orgID := newEventsUC(t)
	starts := time.Date(2026, 5, 1, 10, 0, 0, 0, time.UTC)
	ev, err := uc.Create(context.Background(), CreateEventInput{
		UserID:         ownerID,
		OrganizationID: orgID,
		Name:           "  Конференция  ",
		Description:    "  о складе  ",
		StartsAt:       &starts,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if ev.Name != "Конференция" {
		t.Fatalf("name not trimmed: %q", ev.Name)
	}
	if ev.Description != "о складе" {
		t.Fatalf("description not trimmed: %q", ev.Description)
	}

	list, err := uc.List(context.Background(), ownerID, orgID)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 || list[0].ID != ev.ID {
		t.Fatalf("unexpected list: %+v", list)
	}

	entries, _ := activity.ListByOrganization(context.Background(), orgID, 0)
	if len(entries) != 1 || entries[0].Kind != domain.ActivityEventCreated {
		t.Fatalf("activity not logged: %+v", entries)
	}
}

func TestEventsUseCase_ValidationEmptyName(t *testing.T) {
	uc, _, _, ownerID, orgID := newEventsUC(t)
	if _, err := uc.Create(context.Background(), CreateEventInput{
		UserID:         ownerID,
		OrganizationID: orgID,
		Name:           "  ",
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("expected validation, got %v", err)
	}
}
