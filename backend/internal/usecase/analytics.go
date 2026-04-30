//
// analytics.go
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

package usecase

import (
	"context"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/google/uuid"
)

type AnalyticsUseCase struct {
	items    ItemRepository
	members  OrganizationMemberRepository
	activity ActivityRepository
}

func NewAnalyticsUseCase(
	items ItemRepository,
	members OrganizationMemberRepository,
	activity ActivityRepository,
) *AnalyticsUseCase {
	return &AnalyticsUseCase{
		items:    items,
		members:  members,
		activity: activity,
	}
}

func (uc *AnalyticsUseCase) GetDashboardMetrics(ctx context.Context, userID, orgID uuid.UUID) (*domain.DashboardMetrics, error) {
	_, err := uc.members.FindRole(ctx, orgID, userID)
	if err != nil {
		return nil, err
	}

	inStockStatus := domain.ItemStatusInStock
	items, err := uc.items.ListByOrganization(ctx, orgID, ItemFilter{
		Status: &inStockStatus,
	})
	if err != nil {
		return nil, err
	}

	archivedStatus := domain.ItemStatusArchived
	archivedItems, err := uc.items.ListByOrganization(ctx, orgID, ItemFilter{
		Status: &archivedStatus,
	})
	if err != nil {
		return nil, err
	}

	metrics := &domain.DashboardMetrics{
		TotalItems:      len(items) + len(archivedItems),
		InStockItems:    len(items),
		ArchivedItems:   len(archivedItems),
		ExpiringSoon:    0,
		CategoriesCount: 0,
		StockTrend:      []domain.StockDataPoint{},
		CategoryDist:    []domain.CategoryDistribution{},
		ExpiringItems:   []domain.ExpiringItem{},
	}

	categoryMap := make(map[string]int)
	now := time.Now()
	sevenDaysFromNow := now.AddDate(0, 0, 7)

	for _, item := range items {

		if item.CategoryName != "" {
			categoryMap[item.CategoryName]++
		}

		if item.ExpirationDate != nil && item.ExpirationDate.Before(sevenDaysFromNow) {
			metrics.ExpiringSoon++

			daysUntil := int(item.ExpirationDate.Sub(now).Hours() / 24)
			metrics.ExpiringItems = append(metrics.ExpiringItems, domain.ExpiringItem{
				ID:             item.ID,
				Name:           item.Name,
				Quantity:       item.Quantity,
				ExpirationDate: *item.ExpirationDate,
				DaysUntil:      daysUntil,
			})
		}
	}

	metrics.CategoriesCount = len(categoryMap)
	for name, count := range categoryMap {
		metrics.CategoryDist = append(metrics.CategoryDist, domain.CategoryDistribution{
			CategoryName: name,
			Count:        count,
		})
	}

	for i := 6; i >= 0; i-- {
		date := now.AddDate(0, 0, -i)
		metrics.StockTrend = append(metrics.StockTrend, domain.StockDataPoint{
			Date:     date,
			Quantity: metrics.InStockItems,
		})
	}

	return metrics, nil
}
