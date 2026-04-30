# Item Reservation System — Система резервирования позиций

## Overview

Система резервирования позволяет временно "забронировать" определенное количество товара для конкретной цели (заказ, доставка, производство), не удаляя его из склада. Это критично для предотвращения overselling и координации между участниками организации.

## Business Requirements

### Use Cases

1. **Резервирование под заказ клиента**
   - Менеджер резервирует 10 единиц товара под заказ #12345
   - Товар остается на складе, но помечен как "зарезервировано"
   - Другие участники видят доступное количество = total - reserved

2. **Резервирование для доставки**
   - Водитель резервирует товары для маршрута доставки
   - После доставки резервирование снимается или архивируется

3. **Резервирование для производства**
   - Производство резервирует ингредиенты для партии продукции
   - После использования резервирование закрывается

4. **Автоматическое истечение резервирования**
   - Резервирование с истекшим сроком автоматически освобождается
   - Уведомление создателю резервирования

### Key Features

- ✅ Резервирование части или всего количества позиции
- ✅ Указание причины и деталей резервирования
- ✅ Срок действия резервирования (TTL)
- ✅ История резервирований
- ✅ Автоматическое освобождение по истечении срока
- ✅ Уведомления о резервировании/освобождении
- ✅ Права доступа (кто может резервировать/отменять)

## Database Schema

### Migration: `00022_add_item_reservations.sql`

```sql
-- Create item_reservations table
CREATE TABLE item_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Reservation details
    quantity INT NOT NULL CHECK (quantity > 0),
    reason VARCHAR(50) NOT NULL, -- 'order', 'delivery', 'production', 'other'
    reason_detail TEXT, -- Order number, delivery route, etc.
    reference_id VARCHAR(255), -- External reference (order ID, route ID, etc.)
    
    -- Lifecycle
    reserved_by_user_id UUID NOT NULL REFERENCES users(id),
    reserved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- NULL = no expiration
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'fulfilled', 'cancelled', 'expired'
    fulfilled_at TIMESTAMPTZ,
    fulfilled_by_user_id UUID REFERENCES users(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by_user_id UUID REFERENCES users(id),
    cancellation_reason TEXT,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX idx_item_reservations_item_id ON item_reservations(item_id);
CREATE INDEX idx_item_reservations_organization_id ON item_reservations(organization_id);
CREATE INDEX idx_item_reservations_reserved_by ON item_reservations(reserved_by_user_id);
CREATE INDEX idx_item_reservations_status ON item_reservations(status);
CREATE INDEX idx_item_reservations_expires_at ON item_reservations(expires_at) WHERE expires_at IS NOT NULL AND status = 'active';

-- Partial index for active reservations (most common query)
CREATE INDEX idx_item_reservations_active ON item_reservations(item_id, organization_id) 
WHERE status = 'active';

-- Trigger to update updated_at
CREATE TRIGGER update_item_reservations_updated_at
    BEFORE UPDATE ON item_reservations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add reserved_quantity computed column to items view (optional)
-- This can be a materialized view for performance
CREATE MATERIALIZED VIEW item_reservation_summary AS
SELECT 
    i.id AS item_id,
    i.organization_id,
    COALESCE(SUM(r.quantity), 0) AS total_reserved
FROM items i
LEFT JOIN item_reservations r ON i.id = r.item_id AND r.status = 'active'
GROUP BY i.id, i.organization_id;

CREATE UNIQUE INDEX idx_item_reservation_summary_item ON item_reservation_summary(item_id);
CREATE INDEX idx_item_reservation_summary_org ON item_reservation_summary(organization_id);

-- Refresh function (call periodically or on reservation changes)
CREATE OR REPLACE FUNCTION refresh_item_reservation_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY item_reservation_summary;
END;
$$ LANGUAGE plpgsql;
```

### Validation Constraints

```sql
-- Ensure reservation quantity doesn't exceed available quantity
CREATE OR REPLACE FUNCTION validate_reservation_quantity()
RETURNS TRIGGER AS $$
DECLARE
    item_quantity INT;
    current_reserved INT;
    available INT;
BEGIN
    -- Get item quantity
    SELECT quantity INTO item_quantity
    FROM items
    WHERE id = NEW.item_id;
    
    -- Get current reservations (excluding this one if UPDATE)
    SELECT COALESCE(SUM(quantity), 0) INTO current_reserved
    FROM item_reservations
    WHERE item_id = NEW.item_id 
      AND status = 'active'
      AND (TG_OP = 'INSERT' OR id != NEW.id);
    
    -- Calculate available
    available := item_quantity - current_reserved;
    
    -- Validate
    IF NEW.quantity > available THEN
        RAISE EXCEPTION 'Insufficient quantity: requested %, available %', NEW.quantity, available;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_reservation_quantity_trigger
    BEFORE INSERT OR UPDATE OF quantity ON item_reservations
    FOR EACH ROW
    WHEN (NEW.status = 'active')
    EXECUTE FUNCTION validate_reservation_quantity();
```

## Backend Implementation

### Domain Model

**`backend/internal/domain/reservation.go`**:

```go
package domain

import (
    "time"
    "github.com/google/uuid"
)

type ReservationReason string

const (
    ReservationReasonOrder      ReservationReason = "order"
    ReservationReasonDelivery   ReservationReason = "delivery"
    ReservationReasonProduction ReservationReason = "production"
    ReservationReasonOther      ReservationReason = "other"
)

type ReservationStatus string

const (
    ReservationStatusActive    ReservationStatus = "active"
    ReservationStatusFulfilled ReservationStatus = "fulfilled"
    ReservationStatusCancelled ReservationStatus = "cancelled"
    ReservationStatusExpired   ReservationStatus = "expired"
)

type ItemReservation struct {
    ID             uuid.UUID
    ItemID         uuid.UUID
    OrganizationID uuid.UUID
    
    // Reservation details
    Quantity      int
    Reason        ReservationReason
    ReasonDetail  string
    ReferenceID   string // External reference
    
    // Lifecycle
    ReservedByUserID uuid.UUID
    ReservedAt       time.Time
    ExpiresAt        *time.Time
    
    // Status
    Status              ReservationStatus
    FulfilledAt         *time.Time
    FulfilledByUserID   *uuid.UUID
    CancelledAt         *time.Time
    CancelledByUserID   *uuid.UUID
    CancellationReason  string
    
    // Metadata
    Notes     string
    CreatedAt time.Time
    UpdatedAt time.Time
}

func (r *ItemReservation) IsActive() bool {
    return r.Status == ReservationStatusActive
}

func (r *ItemReservation) IsExpired(now time.Time) bool {
    return r.ExpiresAt != nil && r.ExpiresAt.Before(now)
}

func (r *ItemReservation) CanBeCancelled(userID uuid.UUID, isAdmin bool) bool {
    if r.Status != ReservationStatusActive {
        return false
    }
    // Can cancel own reservation or admin can cancel any
    return r.ReservedByUserID == userID || isAdmin
}

func (r *ItemReservation) CanBeFulfilled(userID uuid.UUID, isAdmin bool) bool {
    if r.Status != ReservationStatusActive {
        return false
    }
    // Can fulfill own reservation or admin can fulfill any
    return r.ReservedByUserID == userID || isAdmin
}
```

### Use Case

**`backend/internal/usecase/reservations.go`**:

```go
package usecase

import (
    "context"
    "time"
    
    "github.com/google/uuid"
    "cstatiWarehouse/internal/domain"
)

type ReservationsUseCase struct {
    repo          ReservationRepository
    itemRepo      ItemRepository
    orgRepo       OrganizationRepository
    broadcaster   WebSocketBroadcaster
    notifications NotificationService
}

type CreateReservationInput struct {
    ItemID         uuid.UUID
    OrganizationID uuid.UUID
    Quantity       int
    Reason         domain.ReservationReason
    ReasonDetail   string
    ReferenceID    string
    ExpiresAt      *time.Time
    Notes          string
}

func (uc *ReservationsUseCase) CreateReservation(ctx context.Context, in CreateReservationInput) (*domain.ItemReservation, error) {
    userID := GetUserIDFromContext(ctx)
    
    // Validate organization membership
    member, err := uc.orgRepo.GetMember(ctx, in.OrganizationID, userID)
    if err != nil {
        return nil, domain.ErrUnauthorized
    }
    
    // Check permissions (members can reserve)
    if member.Role == domain.RoleGuest {
        return nil, domain.ErrForbidden
    }
    
    // Validate item exists and belongs to organization
    item, err := uc.itemRepo.GetByID(ctx, in.ItemID)
    if err != nil {
        return nil, err
    }
    if item.OrganizationID != in.OrganizationID {
        return nil, domain.ErrNotFound
    }
    
    // Check available quantity
    available, err := uc.repo.GetAvailableQuantity(ctx, in.ItemID)
    if err != nil {
        return nil, err
    }
    if in.Quantity > available {
        return nil, domain.ErrInsufficientQuantity
    }
    
    // Create reservation
    reservation := &domain.ItemReservation{
        ID:               uuid.New(),
        ItemID:           in.ItemID,
        OrganizationID:   in.OrganizationID,
        Quantity:         in.Quantity,
        Reason:           in.Reason,
        ReasonDetail:     in.ReasonDetail,
        ReferenceID:      in.ReferenceID,
        ReservedByUserID: userID,
        ReservedAt:       time.Now(),
        ExpiresAt:        in.ExpiresAt,
        Status:           domain.ReservationStatusActive,
        Notes:            in.Notes,
    }
    
    if err := uc.repo.Create(ctx, reservation); err != nil {
        return nil, err
    }
    
    // Broadcast to organization
    uc.broadcaster.BroadcastToOrganization(in.OrganizationID, WebSocketMessage{
        Type: "reservation_created",
        Data: reservation,
    })
    
    // Send notification to item owner (if different from reserver)
    if item.CreatedByUserID != userID {
        uc.notifications.SendReservationCreated(ctx, item.CreatedByUserID, reservation)
    }
    
    return reservation, nil
}

type FulfillReservationInput struct {
    ReservationID uuid.UUID
}

func (uc *ReservationsUseCase) FulfillReservation(ctx context.Context, in FulfillReservationInput) error {
    userID := GetUserIDFromContext(ctx)
    
    reservation, err := uc.repo.GetByID(ctx, in.ReservationID)
    if err != nil {
        return err
    }
    
    // Check permissions
    member, err := uc.orgRepo.GetMember(ctx, reservation.OrganizationID, userID)
    if err != nil {
        return domain.ErrUnauthorized
    }
    
    isAdmin := member.Role == domain.RoleOwner || member.Role == domain.RoleAdmin
    if !reservation.CanBeFulfilled(userID, isAdmin) {
        return domain.ErrForbidden
    }
    
    // Update status
    now := time.Now()
    reservation.Status = domain.ReservationStatusFulfilled
    reservation.FulfilledAt = &now
    reservation.FulfilledByUserID = &userID
    
    if err := uc.repo.Update(ctx, reservation); err != nil {
        return err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(reservation.OrganizationID, WebSocketMessage{
        Type: "reservation_fulfilled",
        Data: reservation,
    })
    
    return nil
}

type CancelReservationInput struct {
    ReservationID uuid.UUID
    Reason        string
}

func (uc *ReservationsUseCase) CancelReservation(ctx context.Context, in CancelReservationInput) error {
    userID := GetUserIDFromContext(ctx)
    
    reservation, err := uc.repo.GetByID(ctx, in.ReservationID)
    if err != nil {
        return err
    }
    
    // Check permissions
    member, err := uc.orgRepo.GetMember(ctx, reservation.OrganizationID, userID)
    if err != nil {
        return domain.ErrUnauthorized
    }
    
    isAdmin := member.Role == domain.RoleOwner || member.Role == domain.RoleAdmin
    if !reservation.CanBeCancelled(userID, isAdmin) {
        return domain.ErrForbidden
    }
    
    // Update status
    now := time.Now()
    reservation.Status = domain.ReservationStatusCancelled
    reservation.CancelledAt = &now
    reservation.CancelledByUserID = &userID
    reservation.CancellationReason = in.Reason
    
    if err := uc.repo.Update(ctx, reservation); err != nil {
        return err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(reservation.OrganizationID, WebSocketMessage{
        Type: "reservation_cancelled",
        Data: reservation,
    })
    
    return nil
}

func (uc *ReservationsUseCase) ListReservations(ctx context.Context, orgID uuid.UUID, itemID *uuid.UUID, status *domain.ReservationStatus) ([]domain.ItemReservation, error) {
    userID := GetUserIDFromContext(ctx)
    
    // Validate membership
    _, err := uc.orgRepo.GetMember(ctx, orgID, userID)
    if err != nil {
        return nil, domain.ErrUnauthorized
    }
    
    return uc.repo.List(ctx, orgID, itemID, status)
}

// Background job to expire reservations
func (uc *ReservationsUseCase) ExpireReservations(ctx context.Context) error {
    expired, err := uc.repo.FindExpired(ctx, time.Now())
    if err != nil {
        return err
    }
    
    for _, reservation := range expired {
        reservation.Status = domain.ReservationStatusExpired
        if err := uc.repo.Update(ctx, &reservation); err != nil {
            // Log error but continue
            continue
        }
        
        // Notify creator
        uc.notifications.SendReservationExpired(ctx, reservation.ReservedByUserID, &reservation)
        
        // Broadcast
        uc.broadcaster.BroadcastToOrganization(reservation.OrganizationID, WebSocketMessage{
            Type: "reservation_expired",
            Data: reservation,
        })
    }
    
    return nil
}
```

### Repository Interface

**`backend/internal/usecase/ports.go`** (add):

```go
type ReservationRepository interface {
    Create(ctx context.Context, reservation *domain.ItemReservation) error
    Update(ctx context.Context, reservation *domain.ItemReservation) error
    GetByID(ctx context.Context, id uuid.UUID) (*domain.ItemReservation, error)
    List(ctx context.Context, orgID uuid.UUID, itemID *uuid.UUID, status *domain.ReservationStatus) ([]domain.ItemReservation, error)
    GetAvailableQuantity(ctx context.Context, itemID uuid.UUID) (int, error)
    FindExpired(ctx context.Context, now time.Time) ([]domain.ItemReservation, error)
    Delete(ctx context.Context, id uuid.UUID) error
}
```

### HTTP Handler

**`backend/internal/adapter/httpapi/reservations_handler.go`**:

```go
package httpapi

import (
    "encoding/json"
    "net/http"
    "time"
    
    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"
    "cstatiWarehouse/internal/usecase"
    "cstatiWarehouse/internal/domain"
)

type ReservationsHandler struct {
    uc *usecase.ReservationsUseCase
}

func NewReservationsHandler(uc *usecase.ReservationsUseCase) *ReservationsHandler {
    return &ReservationsHandler{uc: uc}
}

type createReservationRequest struct {
    ItemID       string  `json:"item_id"`
    Quantity     int     `json:"quantity"`
    Reason       string  `json:"reason"`
    ReasonDetail string  `json:"reason_detail"`
    ReferenceID  string  `json:"reference_id"`
    ExpiresAt    *string `json:"expires_at"` // ISO 8601
    Notes        string  `json:"notes"`
}

func (h *ReservationsHandler) Create(w http.ResponseWriter, r *http.Request) {
    orgID, err := uuid.Parse(chi.URLParam(r, "orgID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid organization ID")
        return
    }
    
    var req createReservationRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    itemID, err := uuid.Parse(req.ItemID)
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid item ID")
        return
    }
    
    var expiresAt *time.Time
    if req.ExpiresAt != nil {
        t, err := time.Parse(time.RFC3339, *req.ExpiresAt)
        if err != nil {
            respondError(w, http.StatusBadRequest, "invalid expires_at format")
            return
        }
        expiresAt = &t
    }
    
    reservation, err := h.uc.CreateReservation(r.Context(), usecase.CreateReservationInput{
        ItemID:         itemID,
        OrganizationID: orgID,
        Quantity:       req.Quantity,
        Reason:         domain.ReservationReason(req.Reason),
        ReasonDetail:   req.ReasonDetail,
        ReferenceID:    req.ReferenceID,
        ExpiresAt:      expiresAt,
        Notes:          req.Notes,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    respondJSON(w, http.StatusCreated, reservation)
}

func (h *ReservationsHandler) List(w http.ResponseWriter, r *http.Request) {
    orgID, err := uuid.Parse(chi.URLParam(r, "orgID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid organization ID")
        return
    }
    
    var itemID *uuid.UUID
    if itemIDStr := r.URL.Query().Get("item_id"); itemIDStr != "" {
        id, err := uuid.Parse(itemIDStr)
        if err != nil {
            respondError(w, http.StatusBadRequest, "invalid item_id")
            return
        }
        itemID = &id
    }
    
    var status *domain.ReservationStatus
    if statusStr := r.URL.Query().Get("status"); statusStr != "" {
        s := domain.ReservationStatus(statusStr)
        status = &s
    }
    
    reservations, err := h.uc.ListReservations(r.Context(), orgID, itemID, status)
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    respondJSON(w, http.StatusOK, reservations)
}

func (h *ReservationsHandler) Fulfill(w http.ResponseWriter, r *http.Request) {
    reservationID, err := uuid.Parse(chi.URLParam(r, "reservationID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid reservation ID")
        return
    }
    
    err = h.uc.FulfillReservation(r.Context(), usecase.FulfillReservationInput{
        ReservationID: reservationID,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}

type cancelReservationRequest struct {
    Reason string `json:"reason"`
}

func (h *ReservationsHandler) Cancel(w http.ResponseWriter, r *http.Request) {
    reservationID, err := uuid.Parse(chi.URLParam(r, "reservationID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid reservation ID")
        return
    }
    
    var req cancelReservationRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    err = h.uc.CancelReservation(r.Context(), usecase.CancelReservationInput{
        ReservationID: reservationID,
        Reason:        req.Reason,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}
```

### Router Integration

**`backend/internal/adapter/httpapi/router.go`** (add):

```go
// Reservations
r.Route("/organizations/{orgID}/reservations", func(r chi.Router) {
    r.Use(authMiddleware)
    r.Post("/", reservationsHandler.Create)
    r.Get("/", reservationsHandler.List)
    r.Post("/{reservationID}/fulfill", reservationsHandler.Fulfill)
    r.Post("/{reservationID}/cancel", reservationsHandler.Cancel)
})
```

## iOS Implementation

### Domain Model

**`ios/cstatiWarehouse/Entity/ItemReservation.swift`**:

```swift
//
//  ItemReservation.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum ReservationReason: String, Codable, CaseIterable {
    case order = "order"
    case delivery = "delivery"
    case production = "production"
    case other = "other"
    
    var title: String {
        switch self {
        case .order: return "Заказ"
        case .delivery: return "Доставка"
        case .production: return "Производство"
        case .other: return "Другое"
        }
    }
    
    var icon: String {
        switch self {
        case .order: return "cart.fill"
        case .delivery: return "shippingbox.fill"
        case .production: return "hammer.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum ReservationStatus: String, Codable {
    case active = "active"
    case fulfilled = "fulfilled"
    case cancelled = "cancelled"
    case expired = "expired"
    
    var title: String {
        switch self {
        case .active: return "Активно"
        case .fulfilled: return "Выполнено"
        case .cancelled: return "Отменено"
        case .expired: return "Истекло"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .fulfilled: return .green
        case .cancelled: return .gray
        case .expired: return .orange
        }
    }
}

struct ItemReservation: Identifiable, Codable, Hashable {
    let id: UUID
    let itemId: UUID
    let organizationId: UUID
    
    let quantity: Int
    let reason: ReservationReason
    let reasonDetail: String
    let referenceId: String?
    
    let reservedByUserId: UUID
    let reservedAt: Date
    let expiresAt: Date?
    
    let status: ReservationStatus
    let fulfilledAt: Date?
    let fulfilledByUserId: UUID?
    let cancelledAt: Date?
    let cancelledByUserId: UUID?
    let cancellationReason: String?
    
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    
    var isActive: Bool {
        status == .active
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }
    
    var displayTitle: String {
        if !reasonDetail.isEmpty {
            return reasonDetail
        }
        return reason.title
    }
    
    var displaySubtitle: String {
        "Количество: \(quantity)"
    }
}
```

### Service Protocol

**`ios/cstatiWarehouse/Services/Reservations/ReservationsServiceProtocol.swift`**:

```swift
//
//  ReservationsServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

protocol ReservationsServiceProtocol: AnyObject {
    func createReservation(
        organizationID: UUID,
        itemID: UUID,
        quantity: Int,
        reason: ReservationReason,
        reasonDetail: String,
        referenceID: String?,
        expiresAt: Date?,
        notes: String,
        completion: @escaping (Result<ItemReservation, ReservationError>) -> Void
    )
    
    func listReservations(
        organizationID: UUID,
        itemID: UUID?,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationError>) -> Void
    )
    
    func fulfillReservation(
        reservationID: UUID,
        completion: @escaping (Result<Void, ReservationError>) -> Void
    )
    
    func cancelReservation(
        reservationID: UUID,
        reason: String,
        completion: @escaping (Result<Void, ReservationError>) -> Void
    )
}

enum ReservationError: Error {
    case networkError
    case insufficientQuantity
    case unauthorized
    case notFound
    case serverError
    case unknown
    
    var message: String {
        switch self {
        case .networkError: return "Ошибка сети"
        case .insufficientQuantity: return "Недостаточно товара для резервирования"
        case .unauthorized: return "Требуется авторизация"
        case .notFound: return "Резервирование не найдено"
        case .serverError: return "Ошибка сервера"
        case .unknown: return "Неизвестная ошибка"
        }
    }
}
```

### UI Integration

**Item Detail Sheet** - показывать доступное количество с учетом резервирований:

```swift
struct ItemDetailSheet: View {
    let item: Item
    let reservations: [ItemReservation]
    
    var totalReserved: Int {
        reservations
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.quantity }
    }
    
    var availableQuantity: Int {
        max(0, item.quantity - totalReserved)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stock info
            HStack {
                VStack(alignment: .leading) {
                    Text("Всего на складе")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.quantity)")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Зарезервировано")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalReserved)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Доступно")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(availableQuantity)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Reservations list
            if !reservations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Резервирования")
                        .font(.headline)
                    
                    ForEach(reservations) { reservation in
                        ReservationRow(reservation: reservation)
                    }
                }
            }
            
            // Reserve button
            Button {
                showReserveSheet = true
            } label: {
                Label("Зарезервировать", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
