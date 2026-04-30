package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func TestAnalyticsUseCase_GetDashboardMetrics(t *testing.T) {
	ctx := context.Background()
	items := newFakeItemRepo()
	members := newFakeMemberRepo()
	activity := newFakeActivityRepo()

	orgID := uuid.New()
	userID := uuid.New()
	now := time.Now().UTC()
	addr := "Москва"

	if err := members.Add(ctx, &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         userID,
		Role:           domain.OrgRoleAdmin,
		JoinedAt:       now,
	}); err != nil {
		t.Fatal(err)
	}

	expSoon := now.AddDate(0, 0, 3)
	expFar := now.AddDate(0, 0, 30)

	if err := items.Create(ctx, &domain.Item{
		ID: uuid.New(), OrganizationID: orgID, HeldByUserID: userID,
		Name: "А", CategoryName: "КатА", Quantity: 2, Status: domain.ItemStatusInStock,
		ExpirationDate: &expSoon, LocationAddress: &addr,
		MeasureUnit: domain.MeasureUnitPiece, CreatedAt: now, UpdatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}
	if err := items.Create(ctx, &domain.Item{
		ID: uuid.New(), OrganizationID: orgID, HeldByUserID: userID,
		Name: "Б", CategoryName: "КатБ", Quantity: 1, Status: domain.ItemStatusInStock,
		ExpirationDate: &expFar, LocationAddress: &addr,
		MeasureUnit: domain.MeasureUnitPiece, CreatedAt: now, UpdatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}
	if err := items.Create(ctx, &domain.Item{
		ID: uuid.New(), OrganizationID: orgID, HeldByUserID: userID,
		Name: "В архиве", CategoryName: "КатА", Quantity: 0, Status: domain.ItemStatusArchived,
		LocationAddress: &addr,
		MeasureUnit:     domain.MeasureUnitPiece, CreatedAt: now, UpdatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}

	uc := NewAnalyticsUseCase(items, members, activity)
	m, err := uc.GetDashboardMetrics(ctx, userID, orgID)
	if err != nil {
		t.Fatal(err)
	}
	if m.TotalItems != 3 || m.InStockItems != 2 || m.ArchivedItems != 1 {
		t.Fatalf("counts: %+v", m)
	}
	if m.ExpiringSoon != 1 || len(m.ExpiringItems) != 1 {
		t.Fatalf("expiring: soon=%d items=%d", m.ExpiringSoon, len(m.ExpiringItems))
	}
	if m.CategoriesCount != 2 {
		t.Fatalf("categories: %d", m.CategoriesCount)
	}
	if len(m.StockTrend) != 7 {
		t.Fatalf("trend len %d", len(m.StockTrend))
	}
}

func TestAnalyticsUseCase_GetDashboardMetrics_forbidden(t *testing.T) {
	ctx := context.Background()
	items := newFakeItemRepo()
	members := newFakeMemberRepo()
	activity := newFakeActivityRepo()
	uc := NewAnalyticsUseCase(items, members, activity)

	if _, err := uc.GetDashboardMetrics(ctx, uuid.New(), uuid.New()); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("expected ErrNotFound for non-member, got %v", err)
	}
}
