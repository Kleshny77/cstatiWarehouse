//
// activity.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package usecase

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// ActivityUseCase выдаёт журнал действий организации.
// Любой участник организации может читать историю.
type ActivityUseCase struct {
	activity ActivityRepository
	members  OrganizationMemberRepository
}

func NewActivityUseCase(activity ActivityRepository, members OrganizationMemberRepository) *ActivityUseCase {
	return &ActivityUseCase{activity: activity, members: members}
}

func (uc *ActivityUseCase) List(ctx context.Context, userID, orgID uuid.UUID, limit int) ([]domain.ActivityEntry, error) {
	if _, err := uc.members.FindRole(ctx, orgID, userID); err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.ErrForbidden
		}
		return nil, err
	}
	return uc.activity.ListByOrganization(ctx, orgID, limit)
}
