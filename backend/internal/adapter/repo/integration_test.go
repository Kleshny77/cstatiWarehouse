//go:build integration

package repo_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/testsupport"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

func TestIntegration_UserRepo_CreateAndQuery(t *testing.T) {
	pool := testsupport.SetupDB(t)
	r := repo.NewUserRepo(pool)

	hash := "hash:secret"
	user := &domain.User{
		ID:           uuid.New(),
		Email:        "alice@example.com",
		Name:         "Alice",
		PasswordHash: &hash,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	if err := r.Create(context.Background(), user); err != nil {
		t.Fatalf("create: %v", err)
	}

	got, err := r.FindByEmail(context.Background(), "alice@example.com")
	if err != nil {
		t.Fatalf("find by email: %v", err)
	}
	if got.ID != user.ID || got.Name != "Alice" {
		t.Errorf("unexpected user: %+v", got)
	}

	duplicate := &domain.User{
		ID:           uuid.New(),
		Email:        "alice@example.com",
		Name:         "Alice II",
		PasswordHash: &hash,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	if err := r.Create(context.Background(), duplicate); !errors.Is(err, domain.ErrEmailAlreadyUsed) {
		t.Errorf("expected ErrEmailAlreadyUsed on duplicate email, got %v", err)
	}

	if _, err := r.FindByEmail(context.Background(), "nobody@example.com"); !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound, got %v", err)
	}
}

func TestIntegration_UserRepo_TelegramLookup(t *testing.T) {
	pool := testsupport.SetupDB(t)
	r := repo.NewUserRepo(pool)

	sub := "tg-42"
	user := &domain.User{
		ID:          uuid.New(),
		Email:       "bob@telegram.local",
		Name:        "Bob",
		TelegramSub: &sub,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	if err := r.Create(context.Background(), user); err != nil {
		t.Fatalf("create: %v", err)
	}
	got, err := r.FindByTelegramSub(context.Background(), "tg-42")
	if err != nil {
		t.Fatalf("find by tg sub: %v", err)
	}
	if got.ID != user.ID {
		t.Errorf("unexpected user: %+v", got)
	}
}

func TestIntegration_ItemRepo_Lifecycle(t *testing.T) {
	pool := testsupport.SetupDB(t)
	users := repo.NewUserRepo(pool)
	items := repo.NewItemRepo(pool)

	hash := "hash:x"
	owner := &domain.User{
		ID: uuid.New(), Email: "owner@x.com", Name: "O", PasswordHash: &hash,
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	if err := users.Create(context.Background(), owner); err != nil {
		t.Fatalf("create owner: %v", err)
	}

	now := time.Now().UTC()
	item := &domain.Item{
		ID: uuid.New(), OwnerID: owner.ID,
		Name: "Кола", Description: "0.5л", CategoryName: "Напитки", Quantity: 3,
		Status: domain.ItemStatusInStock, CreatedAt: now, UpdatedAt: now,
	}
	if err := items.Create(context.Background(), item); err != nil {
		t.Fatalf("create item: %v", err)
	}

	list, err := items.ListByOwner(context.Background(), owner.ID, usecase.ItemFilter{})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1 item, got %d", len(list))
	}

	reason := domain.ArchiveReasonUsedAtEvent
	archivedAt := time.Now().UTC()
	item.Status = domain.ItemStatusArchived
	item.ArchiveReason = &reason
	item.ArchivedAt = &archivedAt
	item.UpdatedAt = archivedAt
	if err := items.Update(context.Background(), item); err != nil {
		t.Fatalf("update: %v", err)
	}

	inStock := domain.ItemStatusInStock
	onlyInStock, err := items.ListByOwner(context.Background(), owner.ID, usecase.ItemFilter{Status: &inStock})
	if err != nil {
		t.Fatalf("list in_stock: %v", err)
	}
	if len(onlyInStock) != 0 {
		t.Errorf("expected 0 in_stock items after archive, got %d", len(onlyInStock))
	}

	archivedStatus := domain.ItemStatusArchived
	onlyArchived, err := items.ListByOwner(context.Background(), owner.ID, usecase.ItemFilter{Status: &archivedStatus})
	if err != nil {
		t.Fatalf("list archived: %v", err)
	}
	if len(onlyArchived) != 1 {
		t.Fatalf("expected 1 archived item, got %d", len(onlyArchived))
	}
	if onlyArchived[0].ArchiveReason == nil || *onlyArchived[0].ArchiveReason != domain.ArchiveReasonUsedAtEvent {
		t.Errorf("archive reason not persisted: %+v", onlyArchived[0].ArchiveReason)
	}

	cats, err := items.ListCategoriesByOwner(context.Background(), owner.ID)
	if err != nil {
		t.Fatalf("categories: %v", err)
	}
	if len(cats) != 1 || cats[0] != "Напитки" {
		t.Errorf("unexpected categories: %+v", cats)
	}

	if err := items.Delete(context.Background(), item.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := items.FindByID(context.Background(), item.ID); !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound after delete, got %v", err)
	}
}
