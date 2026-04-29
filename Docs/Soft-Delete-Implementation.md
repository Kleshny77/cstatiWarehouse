# Soft Delete Implementation (Undo/Redo)

## Overview

Soft delete allows items to be "deleted" without permanently removing them from the database. This enables:
- **Undo functionality** - Restore accidentally deleted items
- **Audit trail** - Track who deleted what and when
- **Data recovery** - Recover items within a retention period
- **Compliance** - Meet data retention requirements

## Database Schema

### Migration

**File**: [`backend/migrations/00021_add_soft_delete.sql`](../backend/migrations/00021_add_soft_delete.sql)

**Changes**:
```sql
ALTER TABLE items ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE items ADD COLUMN deleted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL;
```

**Indexes**:
```sql
-- Filter out deleted items (most common query)
CREATE INDEX idx_items_deleted_at 
    ON items(deleted_at) WHERE deleted_at IS NULL;

-- Find deleted items (for restore/cleanup)
CREATE INDEX idx_items_deleted_at_not_null 
    ON items(deleted_at DESC) WHERE deleted_at IS NOT NULL;

-- Deleted items by organization
CREATE INDEX idx_items_org_deleted 
    ON items(organization_id, deleted_at DESC) WHERE deleted_at IS NOT NULL;
```

### Domain Model

**File**: [`backend/internal/domain/item.go`](../backend/internal/domain/item.go)

**Fields Added**:
```go
type Item struct {
    // ... existing fields
    DeletedAt       *time.Time
    DeletedByUserID *uuid.UUID
    // ... existing fields
}

func (i *Item) IsDeleted() bool {
    return i.DeletedAt != nil
}

func (i *Item) IsActive() bool {
    return i.DeletedAt == nil
}
```

## Implementation Plan

### Phase 1: Backend Infrastructure (COMPLETED)

✅ Database migration with `deleted_at` and `deleted_by_user_id`
✅ Indexes for efficient queries
✅ Domain model updates

### Phase 2: Repository Layer (TODO)

**Update `ItemRepo.Delete`**:
```go
// Soft delete instead of hard delete
func (r *ItemRepo) Delete(ctx context.Context, id uuid.UUID, deletedBy uuid.UUID) error {
    tag, err := r.pool.Exec(ctx, `
        UPDATE items 
        SET deleted_at = NOW(), deleted_by_user_id = $2, updated_at = NOW()
        WHERE id = $1 AND deleted_at IS NULL
    `, id, deletedBy)
    // ...
}
```

**Add `ItemRepo.Restore`**:
```go
func (r *ItemRepo) Restore(ctx context.Context, id uuid.UUID) error {
    tag, err := r.pool.Exec(ctx, `
        UPDATE items 
        SET deleted_at = NULL, deleted_by_user_id = NULL, updated_at = NOW()
        WHERE id = $1 AND deleted_at IS NOT NULL
    `, id)
    // ...
}
```

**Add `ItemRepo.ListDeleted`**:
```go
func (r *ItemRepo) ListDeleted(ctx context.Context, orgID uuid.UUID, limit, offset int) ([]domain.Item, error) {
    rows, err := r.pool.Query(ctx, `
        SELECT * FROM items
        WHERE organization_id = $1 AND deleted_at IS NOT NULL
        ORDER BY deleted_at DESC
        LIMIT $2 OFFSET $3
    `, orgID, limit, offset)
    // ...
}
```

**Update `ItemRepo.ListByOrganization`**:
```go
// Add WHERE deleted_at IS NULL to all queries
func (r *ItemRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID, filter usecase.ItemFilter) ([]domain.Item, error) {
    rows, err := r.pool.Query(ctx, `
        SELECT * FROM items
        WHERE organization_id = $1 
          AND deleted_at IS NULL  -- Filter out deleted items
          AND status = $2
        ORDER BY created_at DESC
    `, orgID, filter.Status)
    // ...
}
```

### Phase 3: Use Case Layer (TODO)

**Update `WarehouseUseCase.Delete`**:
```go
func (uc *WarehouseUseCase) Delete(ctx context.Context, in DeleteItemInput) error {
    // Soft delete with user tracking
    return uc.repo.Delete(ctx, in.ItemID, in.DeletedByUserID)
}
```

**Add `WarehouseUseCase.Restore`**:
```go
type RestoreItemInput struct {
    ItemID         uuid.UUID
    RestoredByUserID uuid.UUID
}

func (uc *WarehouseUseCase) Restore(ctx context.Context, in RestoreItemInput) (*domain.Item, error) {
    // Verify permissions
    // Restore item
    // Broadcast update via WebSocket
    // Log activity
}
```

**Add `WarehouseUseCase.ListDeleted`**:
```go
func (uc *WarehouseUseCase) ListDeleted(ctx context.Context, orgID uuid.UUID, limit, offset int) ([]domain.Item, error) {
    return uc.repo.ListDeleted(ctx, orgID, limit, offset)
}
```

### Phase 4: HTTP API (TODO)

**Add Restore Endpoint**:
```go
// POST /items/{id}/restore
func (h *WarehouseHandler) Restore(w http.ResponseWriter, r *http.Request) {
    itemID := uuid.MustParse(r.PathValue("id"))
    userID, _ := currentUserID(r)
    
    item, err := h.uc.Restore(ctx, usecase.RestoreItemInput{
        ItemID:           itemID,
        RestoredByUserID: userID,
    })
    // ...
}
```

**Add List Deleted Endpoint**:
```go
// GET /items/deleted
func (h *WarehouseHandler) ListDeleted(w http.ResponseWriter, r *http.Request) {
    orgID := uuid.MustParse(r.URL.Query().Get("organization_id"))
    items, err := h.uc.ListDeleted(ctx, orgID, 50, 0)
    // ...
}
```

### Phase 5: iOS Integration (TODO)

**Add Restore Method**:
```swift
// ApiWarehouseService.swift
func restoreItem(id: UUID, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
    apiClient.request(
        method: .post,
        path: "/items/\(id.uuidString)/restore",
        completion: { (result: Result<ItemResponseDTO, APIError>) in
            completion(Self.mapItemResult(result))
        }
    )
}
```

**Add Deleted Items View**:
```swift
// DeletedItemsView.swift
struct DeletedItemsView: View {
    @Bindable var presenter: DeletedItemsPresenter
    
    var body: some View {
        List(presenter.deletedItems) { item in
            DeletedItemRow(item: item) {
                presenter.restoreItem(item)
            }
        }
    }
}
```

## Retention Policy

### Auto-Cleanup (Optional)

**Cron Job** to permanently delete old soft-deleted items:

```sql
-- Delete items soft-deleted more than 30 days ago
DELETE FROM items 
WHERE deleted_at IS NOT NULL 
  AND deleted_at < NOW() - INTERVAL '30 days';
```

**Configuration**:
```bash
# Environment variable
SOFT_DELETE_RETENTION_DAYS=30
```

## Security Considerations

### 1. Permission Checks

Only allow restore if:
- User is member of the organization
- User has appropriate role (admin/owner)
- Item was deleted less than retention period ago

### 2. Audit Logging

Log all delete and restore operations:
```go
activityRepo.Log(ctx, domain.Activity{
    Type:           "item_deleted",
    ItemID:         itemID,
    UserID:         deletedByUserID,
    OrganizationID: orgID,
})
```

### 3. Cascade Behavior

**Child items**: When parent is soft-deleted, soft-delete all children
**Archive events**: Keep archive events even for deleted items (audit trail)

## UI/UX Design

### Delete Confirmation

```
┌─────────────────────────────────────┐
│  Delete "Coca-Cola 0.5L"?          │
│                                     │
│  This item will be moved to trash  │
│  and can be restored within 30     │
│  days.                              │
│                                     │
│  [Cancel]  [Delete]                │
└─────────────────────────────────────┘
```

### Trash/Deleted Items View

```
┌─────────────────────────────────────┐
│  Deleted Items                      │
│  ─────────────────────────────────  │
│  🗑️ Coca-Cola 0.5L                 │
│     Deleted 2 days ago by John      │
│     [Restore] [Delete Forever]      │
│                                     │
│  🗑️ Sprite 1L                      │
│     Deleted 5 days ago by Jane      │
│     [Restore] [Delete Forever]      │
└─────────────────────────────────────┘
```

### Restore Confirmation

```
┌─────────────────────────────────────┐
│  Restore "Coca-Cola 0.5L"?         │
│                                     │
│  This item will be moved back to   │
│  your warehouse.                    │
│                                     │
│  [Cancel]  [Restore]               │
└─────────────────────────────────────┘
```

## Testing

### Unit Tests

```go
func TestItemRepo_SoftDelete(t *testing.T) {
    // Create item
    // Soft delete
    // Verify deleted_at is set
    // Verify item not in active list
    // Verify item in deleted list
}

func TestItemRepo_Restore(t *testing.T) {
    // Create and soft delete item
    // Restore item
    // Verify deleted_at is NULL
    // Verify item in active list
}
```

### Integration Tests

```go
func TestWarehouseUseCase_DeleteAndRestore(t *testing.T) {
    // Delete item via use case
    // Verify WebSocket broadcast
    // Verify activity log
    // Restore item
    // Verify WebSocket broadcast
    // Verify activity log
}
```

## Migration Strategy

### Backward Compatibility

1. **Add columns** with DEFAULT NULL (non-breaking)
2. **Update queries** to filter `deleted_at IS NULL`
3. **Deploy backend** with soft delete support
4. **Update iOS app** with restore functionality
5. **Enable auto-cleanup** after retention period

### Rollback Plan

If issues arise:
1. Restore deleted items: `UPDATE items SET deleted_at = NULL WHERE deleted_at IS NOT NULL`
2. Roll back migration: `goose down`
3. Deploy previous version

## Performance Impact

### Query Performance

**Before** (hard delete):
```sql
SELECT * FROM items WHERE organization_id = ?
-- No additional filtering needed
```

**After** (soft delete):
```sql
SELECT * FROM items WHERE organization_id = ? AND deleted_at IS NULL
-- Additional filter, but indexed
```

**Impact**: Minimal (< 5ms) due to partial index on `deleted_at IS NULL`

### Storage Impact

- Deleted items remain in database
- Estimate: ~10% storage increase
- Mitigated by auto-cleanup after retention period

## Future Enhancements

1. **Bulk restore** - Restore multiple items at once
2. **Restore with history** - Show what changed since deletion
3. **Permanent delete** - Allow admins to permanently delete
4. **Export deleted items** - Download deleted items as CSV
5. **Restore notifications** - Notify team when item is restored

## Resources

- [Soft Delete Pattern](https://www.martinfowler.com/eaaCatalog/softDelete.html)
- [PostgreSQL Partial Indexes](https://www.postgresql.org/docs/current/indexes-partial.html)
- [Audit Trail Best Practices](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
