package domain

import (
	"time"

	"github.com/google/uuid"
)

type DashboardMetrics struct {
	TotalItems      int                    `json:"total_items"`
	InStockItems    int                    `json:"in_stock_items"`
	ArchivedItems   int                    `json:"archived_items"`
	ExpiringSoon    int                    `json:"expiring_soon"`
	CategoriesCount int                    `json:"categories_count"`
	StockTrend      []StockDataPoint       `json:"stock_trend"`
	CategoryDist    []CategoryDistribution `json:"category_distribution"`
	ExpiringItems   []ExpiringItem         `json:"expiring_items"`
}

type StockDataPoint struct {
	Date     time.Time `json:"date"`
	Quantity int       `json:"quantity"`
}

type CategoryDistribution struct {
	CategoryName string `json:"category_name"`
	Count        int    `json:"count"`
}

type ExpiringItem struct {
	ID             uuid.UUID `json:"id"`
	Name           string    `json:"name"`
	Quantity       int       `json:"quantity"`
	ExpirationDate time.Time `json:"expiration_date"`
	DaysUntil      int       `json:"days_until"`
}
