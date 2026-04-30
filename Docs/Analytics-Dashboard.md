# Analytics Dashboard

## Overview

Enhance the Overview tab (3rd tab) with comprehensive analytics and visualizations:
- **Inventory metrics** - Total items, stock value, categories
- **Trend charts** - Stock changes over time
- **Expiration insights** - Items expiring soon
- **Activity timeline** - Recent warehouse operations
- **Team statistics** - Member contributions

## Current Implementation

**File**: [`ios/cstatiWarehouse/Scenes/Overview/OverviewView.swift`](../ios/cstatiWarehouse/Scenes/Overview/OverviewView.swift)

**Current Features**:
- Basic organization summary
- Member list
- Simple statistics

## Enhanced Dashboard Design

### 1. Key Metrics Cards

```swift
struct MetricsCardsView: View {
    let metrics: DashboardMetrics
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Всего позиций",
                    value: "\(metrics.totalItems)",
                    icon: "cube.box",
                    color: .blue
                )
                
                MetricCard(
                    title: "На складе",
                    value: "\(metrics.inStockItems)",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                MetricCard(
                    title: "Истекает скоро",
                    value: "\(metrics.expiringSoon)",
                    icon: "clock.badge.exclamationmark",
                    color: .orange
                )
                
                MetricCard(
                    title: "Категорий",
                    value: "\(metrics.categoriesCount)",
                    icon: "folder",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}
```

### 2. Stock Trend Chart

```swift
import Charts

struct StockTrendChart: View {
    let data: [StockDataPoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Динамика склада")
                .font(.headline)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Дата", point.date),
                    y: .value("Количество", point.quantity)
                )
                .foregroundStyle(.blue)
                
                AreaMark(
                    x: .value("Дата", point.date),
                    y: .value("Количество", point.quantity)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct StockDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let quantity: Int
}
```

### 3. Category Distribution

```swift
struct CategoryDistributionChart: View {
    let categories: [CategoryData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Распределение по категориям")
                .font(.headline)
            
            Chart(categories) { category in
                BarMark(
                    x: .value("Количество", category.count),
                    y: .value("Категория", category.name)
                )
                .foregroundStyle(by: .value("Категория", category.name))
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}
```

### 4. Expiration Timeline

```swift
struct ExpirationTimelineView: View {
    let items: [ExpiringItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Истекает в ближайшее время")
                .font(.headline)
            
            ForEach(items) { item in
                HStack {
                    Image(systemName: expirationIcon(for: item))
                        .foregroundColor(expirationColor(for: item))
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.subheadline)
                        Text(expirationText(for: item))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(item.quantity) шт")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    func expirationIcon(for item: ExpiringItem) -> String {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: item.expirationDate).day ?? 0
        if daysUntil <= 1 { return "exclamationmark.triangle.fill" }
        if daysUntil <= 3 { return "exclamationmark.circle.fill" }
        return "clock.fill"
    }
}
```

### 5. Activity Feed

```swift
struct ActivityFeedView: View {
    let activities: [ActivityEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последняя активность")
                .font(.headline)
            
            ForEach(activities.prefix(10)) { activity in
                HStack(spacing: 12) {
                    Image(systemName: activity.icon)
                        .foregroundColor(activity.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.subheadline)
                        Text(activity.timestamp.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
```

## Backend Analytics API

### Endpoint: GET /analytics/dashboard

```go
// backend/internal/adapter/httpapi/analytics_handler.go

type DashboardMetrics struct {
    TotalItems      int                    `json:"total_items"`
    InStockItems    int                    `json:"in_stock_items"`
    ArchivedItems   int                    `json:"archived_items"`
    ExpiringSoon    int                    `json:"expiring_soon"`
    CategoriesCount int                    `json:"categories_count"`
    StockTrend      []StockDataPoint       `json:"stock_trend"`
    CategoryDist    []CategoryDistribution `json:"category_distribution"`
    RecentActivity  []ActivityEntry        `json:"recent_activity"`
}

func (h *AnalyticsHandler) GetDashboard(w http.ResponseWriter, r *http.Request) {
    orgID := uuid.MustParse(r.URL.Query().Get("organization_id"))
    
    metrics, err := h.uc.GetDashboardMetrics(ctx, orgID)
    if err != nil {
        writeError(w, r, err)
        return
    }
    
    writeJSON(w, http.StatusOK, metrics)
}
```

### Use Case Implementation

```go
// backend/internal/usecase/analytics.go

type AnalyticsUseCase struct {
    itemRepo     ItemRepository
    activityRepo ActivityRepository
}

func (uc *AnalyticsUseCase) GetDashboardMetrics(ctx context.Context, orgID uuid.UUID) (*DashboardMetrics, error) {
    // Get total items count
    totalItems, err := uc.itemRepo.CountByOrganization(ctx, orgID)
    if err != nil {
        return nil, err
    }
    
    // Get in-stock items count
    inStockItems, err := uc.itemRepo.CountByStatus(ctx, orgID, domain.ItemStatusInStock)
    if err != nil {
        return nil, err
    }
    
    // Get expiring soon count (next 7 days)
    expiringSoon, err := uc.itemRepo.CountExpiringSoon(ctx, orgID, 7*24*time.Hour)
    if err != nil {
        return nil, err
    }
    
    // Get stock trend (last 30 days)
    stockTrend, err := uc.itemRepo.GetStockTrend(ctx, orgID, 30)
    if err != nil {
        return nil, err
    }
    
    // Get category distribution
    categoryDist, err := uc.itemRepo.GetCategoryDistribution(ctx, orgID)
    if err != nil {
        return nil, err
    }
    
    // Get recent activity
    recentActivity, err := uc.activityRepo.ListRecent(ctx, orgID, 20)
    if err != nil {
        return nil, err
    }
    
    return &DashboardMetrics{
        TotalItems:      totalItems,
        InStockItems:    inStockItems,
        ExpiringSoon:    expiringSoon,
        StockTrend:      stockTrend,
        CategoryDist:    categoryDist,
        RecentActivity:  recentActivity,
    }, nil
}
```

## Database Queries

### Stock Trend Query

```sql
-- Get daily stock counts for last 30 days
SELECT 
    DATE(created_at) as date,
    COUNT(*) as quantity
FROM items
WHERE organization_id = $1
  AND created_at >= NOW() - INTERVAL '30 days'
  AND deleted_at IS NULL
GROUP BY DATE(created_at)
ORDER BY date ASC;
```

### Category Distribution Query

```sql
-- Get item count by category
SELECT 
    category_name,
    COUNT(*) as count
FROM items
WHERE organization_id = $1
  AND status = 'in_stock'
  AND deleted_at IS NULL
GROUP BY category_name
ORDER BY count DESC
LIMIT 10;
```

## iOS Integration

### OverviewPresenter Enhancement

```swift
@Observable
final class OverviewPresenter {
    var dashboardMetrics: DashboardMetrics?
    var isLoadingMetrics = false
    
    func loadDashboardMetrics() {
        guard let orgID = activeOrganization?.id else { return }
        
        isLoadingMetrics = true
        analyticsService.fetchDashboardMetrics(organizationID: orgID) { [weak self] result in
            self?.isLoadingMetrics = false
            switch result {
            case .success(let metrics):
                self?.dashboardMetrics = metrics
            case .failure(let error):
                self?.handleError(error)
            }
        }
    }
}
```

### OverviewView Layout

```swift
struct OverviewView: View {
    @Bindable var presenter: OverviewPresenter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Key Metrics Cards
                if let metrics = presenter.dashboardMetrics {
                    MetricsCardsView(metrics: metrics)
                    
                    // Stock Trend Chart
                    StockTrendChart(data: metrics.stockTrend)
                    
                    // Category Distribution
                    CategoryDistributionChart(categories: metrics.categoryDistribution)
                    
                    // Expiration Timeline
                    ExpirationTimelineView(items: metrics.expiringSoonItems)
                    
                    // Activity Feed
                    ActivityFeedView(activities: metrics.recentActivity)
                }
            }
            .padding()
        }
        .navigationTitle("Аналитика")
        .onAppear {
            presenter.loadDashboardMetrics()
        }
        .refreshable {
            await presenter.refreshMetrics()
        }
    }
}
```

## Performance Considerations

### Caching Strategy

```swift
// Cache metrics for 5 minutes
class AnalyticsCache {
    private var cachedMetrics: DashboardMetrics?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    func get() -> DashboardMetrics? {
        guard let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheDuration else {
            return nil
        }
        return cachedMetrics
    }
    
    func set(_ metrics: DashboardMetrics) {
        cachedMetrics = metrics
        cacheTimestamp = Date()
    }
}
```

### Backend Optimization

```go
// Use materialized view for expensive aggregations
CREATE MATERIALIZED VIEW dashboard_metrics_cache AS
SELECT 
    organization_id,
    COUNT(*) FILTER (WHERE status = 'in_stock') as in_stock_count,
    COUNT(*) FILTER (WHERE status = 'archived') as archived_count,
    COUNT(*) FILTER (WHERE expiration_date < NOW() + INTERVAL '7 days') as expiring_soon,
    COUNT(DISTINCT category_name) as categories_count
FROM items
WHERE deleted_at IS NULL
GROUP BY organization_id;

-- Refresh every hour
CREATE INDEX ON dashboard_metrics_cache(organization_id);
```

## Future Enhancements

1. **Export to PDF/Excel** - Download analytics reports
2. **Custom Date Ranges** - Filter by specific periods
3. **Comparison Mode** - Compare periods (this month vs last month)
4. **Predictive Analytics** - Forecast stock needs
5. **Team Leaderboard** - Most active members
6. **Cost Tracking** - Total inventory value
7. **Waste Analysis** - Track expired/disposed items

## Resources

- [Swift Charts Documentation](https://developer.apple.com/documentation/charts)
- [Dashboard Design Best Practices](https://www.nngroup.com/articles/dashboard-design/)
- [Data Visualization Guide](https://www.tableau.com/learn/articles/data-visualization)
