package repo

import (
	"context"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ExpirationCandidateAdapter struct {
	repo *ExpirationNotificationRepo
}

func NewExpirationCandidateAdapter(r *ExpirationNotificationRepo) *ExpirationCandidateAdapter {
	return &ExpirationCandidateAdapter{repo: r}
}

func (a *ExpirationCandidateAdapter) ListItemsExpiringWithin(ctx context.Context, now time.Time, horizonDays int) ([]usecase.ExpirationCandidate, error) {
	src, err := a.repo.ListItemsExpiringWithin(ctx, now, horizonDays)
	if err != nil {
		return nil, err
	}
	out := make([]usecase.ExpirationCandidate, len(src))
	for i, c := range src {
		out[i] = usecase.ExpirationCandidate{
			ItemID:         c.ItemID,
			OrganizationID: c.OrganizationID,
			HeldByUserID:   c.HeldByUserID,
			ItemName:       c.ItemName,
			ExpirationDate: c.ExpirationDate,
			ImageURL:       c.ImageURL,
		}
	}
	return out, nil
}
