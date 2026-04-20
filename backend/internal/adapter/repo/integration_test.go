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

// seedUserWithOrg создаёт пользователя и его персональную организацию
// вместе с записью о членстве с ролью owner. Возвращает (userID, orgID).
func seedUserWithOrg(t *testing.T, users *repo.UserRepo, orgs *repo.OrganizationRepo, members *repo.MemberRepo, email, name string) (uuid.UUID, uuid.UUID) {
	t.Helper()
	hash := "hash:x"
	user := &domain.User{
		ID: uuid.New(), Email: email, Name: name, PasswordHash: &hash,
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	if err := users.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}
	now := time.Now().UTC()
	org := &domain.Organization{
		ID: uuid.New(), Name: "Склад " + name, OwnerID: user.ID, IsPersonal: true,
		CreatedAt: now, UpdatedAt: now,
	}
	if err := orgs.Create(context.Background(), org); err != nil {
		t.Fatalf("create org: %v", err)
	}
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: org.ID, UserID: user.ID, Role: domain.OrgRoleOwner, JoinedAt: now,
	}); err != nil {
		t.Fatalf("add member: %v", err)
	}
	return user.ID, org.ID
}

func TestIntegration_ItemRepo_Lifecycle(t *testing.T) {
	pool := testsupport.SetupDB(t)
	users := repo.NewUserRepo(pool)
	orgs := repo.NewOrganizationRepo(pool)
	members := repo.NewMemberRepo(pool)
	items := repo.NewItemRepo(pool)

	userID, orgID := seedUserWithOrg(t, users, orgs, members, "owner@x.com", "O")

	now := time.Now().UTC()
	item := &domain.Item{
		ID: uuid.New(), OrganizationID: orgID, HeldByUserID: userID,
		Name: "Кола", Description: "0.5л", CategoryName: "Напитки", Quantity: 3,
		Status: domain.ItemStatusInStock, CreatedAt: now, UpdatedAt: now,
	}
	if err := items.Create(context.Background(), item); err != nil {
		t.Fatalf("create item: %v", err)
	}

	list, err := items.ListByOrganization(context.Background(), orgID, usecase.ItemFilter{})
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
	onlyInStock, err := items.ListByOrganization(context.Background(), orgID, usecase.ItemFilter{Status: &inStock})
	if err != nil {
		t.Fatalf("list in_stock: %v", err)
	}
	if len(onlyInStock) != 0 {
		t.Errorf("expected 0 in_stock items after archive, got %d", len(onlyInStock))
	}

	archivedStatus := domain.ItemStatusArchived
	onlyArchived, err := items.ListByOrganization(context.Background(), orgID, usecase.ItemFilter{Status: &archivedStatus})
	if err != nil {
		t.Fatalf("list archived: %v", err)
	}
	if len(onlyArchived) != 1 {
		t.Fatalf("expected 1 archived item, got %d", len(onlyArchived))
	}
	if onlyArchived[0].ArchiveReason == nil || *onlyArchived[0].ArchiveReason != domain.ArchiveReasonUsedAtEvent {
		t.Errorf("archive reason not persisted: %+v", onlyArchived[0].ArchiveReason)
	}

	cats, err := items.ListCategoriesByOrganization(context.Background(), orgID)
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

func TestIntegration_OrganizationRepo_AndMembers(t *testing.T) {
	pool := testsupport.SetupDB(t)
	users := repo.NewUserRepo(pool)
	orgs := repo.NewOrganizationRepo(pool)
	members := repo.NewMemberRepo(pool)

	ownerID, orgID := seedUserWithOrg(t, users, orgs, members, "owner-org@x.com", "Owner")

	// Второй юзер добавляется участником.
	hash := "hash:x"
	second := &domain.User{
		ID: uuid.New(), Email: "member@x.com", Name: "M", PasswordHash: &hash,
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	if err := users.Create(context.Background(), second); err != nil {
		t.Fatalf("create second user: %v", err)
	}
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID, UserID: second.ID, Role: domain.OrgRoleMember, JoinedAt: time.Now().UTC(),
	}); err != nil {
		t.Fatalf("add second member: %v", err)
	}

	// Дубликат членства → ErrAlreadyMember.
	dupErr := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID, UserID: second.ID, Role: domain.OrgRoleMember, JoinedAt: time.Now().UTC(),
	})
	if !errors.Is(dupErr, domain.ErrAlreadyMember) {
		t.Errorf("expected ErrAlreadyMember, got %v", dupErr)
	}

	// Списки членов и ролей.
	list, err := members.ListByOrganization(context.Background(), orgID)
	if err != nil {
		t.Fatalf("list members: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 members, got %d", len(list))
	}

	role, err := members.FindRole(context.Background(), orgID, ownerID)
	if err != nil || role != domain.OrgRoleOwner {
		t.Errorf("owner role wrong: role=%s err=%v", role, err)
	}

	// Обновление роли.
	if err := members.UpdateRole(context.Background(), orgID, second.ID, domain.OrgRoleAdmin); err != nil {
		t.Fatalf("update role: %v", err)
	}
	role, _ = members.FindRole(context.Background(), orgID, second.ID)
	if role != domain.OrgRoleAdmin {
		t.Errorf("expected admin role after update, got %s", role)
	}

	// Организации пользователя.
	mine, err := orgs.ListByUser(context.Background(), second.ID)
	if err != nil {
		t.Fatalf("list orgs by user: %v", err)
	}
	if len(mine) != 1 || mine[0].Role != domain.OrgRoleAdmin {
		t.Errorf("unexpected orgs for second user: %+v", mine)
	}
}
