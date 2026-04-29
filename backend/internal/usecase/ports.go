package usecase

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type Clock interface {
	Now() time.Time
}

type PasswordHasher interface {
	Hash(password string) (string, error)
	Verify(hash, password string) error
}

type TokenIssuer interface {
	IssueAccessToken(userID uuid.UUID, issuedAt time.Time) (token string, expiresAt time.Time, err error)
	ParseAccessToken(token string) (userID uuid.UUID, err error)
}

type RefreshTokenGenerator interface {
	Generate() (plaintext string, hash string, err error)
	Hash(plaintext string) string
}

type TelegramVerifier interface {
	Verify(ctx context.Context, idToken string) (domain.TelegramClaims, error)
}

type GoogleVerifier interface {
	Verify(ctx context.Context, idToken string) (domain.GoogleIDClaims, error)
}

type UserProfileUpdate struct {
	Name      *string
	LastName  *string
	AvatarURL *string
}

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*domain.User, error)
	FindByTelegramSub(ctx context.Context, sub string) (*domain.User, error)
	FindByGoogleSub(ctx context.Context, sub string) (*domain.User, error)
	UpdateProfile(ctx context.Context, id uuid.UUID, patch UserProfileUpdate, now time.Time) (*domain.User, error)
}

type RefreshTokenRepository interface {
	Create(ctx context.Context, token *domain.RefreshToken) error
	FindByHash(ctx context.Context, hash string) (*domain.RefreshToken, error)
	Revoke(ctx context.Context, hash string, at time.Time) error
}

type ItemFilter struct {
	Status       *domain.ItemStatus
	HeldByUserID *uuid.UUID
}

type ItemRepository interface {
	Create(ctx context.Context, item *domain.Item) error
	// Update сохраняет позицию. Если expectedUpdatedAt != nil, обновление выполняется
	// только при совпадении updated_at (оптимистичная блокировка).
	Update(ctx context.Context, item *domain.Item, expectedUpdatedAt *time.Time) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Item, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error)
	Delete(ctx context.Context, id uuid.UUID) error
	ListCategoriesByOrganization(ctx context.Context, orgID uuid.UUID) ([]string, error)
	RecordArchiveEvent(ctx context.Context, item *domain.Item, event *domain.ArchiveEvent) error
	ListArchiveEvents(ctx context.Context, orgID uuid.UUID) ([]domain.ArchiveEvent, error)
	HasChildRows(ctx context.Context, parentID uuid.UUID) (bool, error)
	CountInStockChildrenWithPositiveQuantity(ctx context.Context, parentID uuid.UUID) (int64, error)
}

type OrganizationPatch struct {
	Name *string
}

type OrganizationRepository interface {
	Create(ctx context.Context, org *domain.Organization) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error)
	ListByUser(ctx context.Context, userID uuid.UUID) ([]OrganizationWithRole, error)
	Update(ctx context.Context, id uuid.UUID, patch OrganizationPatch, now time.Time) (*domain.Organization, error)
	SetOwner(ctx context.Context, id uuid.UUID, newOwnerID uuid.UUID, now time.Time) error
	Delete(ctx context.Context, id uuid.UUID) error
	TransferOwnershipAtomic(ctx context.Context, orgID, fromID, toID uuid.UUID, now time.Time) error
}

type OrganizationWithRole struct {
	Organization domain.Organization
	Role         domain.OrgRole
}

type OrganizationMemberRepository interface {
	Add(ctx context.Context, member *domain.OrganizationMember) error
	Remove(ctx context.Context, orgID, userID uuid.UUID) error
	UpdateRole(ctx context.Context, orgID, userID uuid.UUID, role domain.OrgRole) error
	FindRole(ctx context.Context, orgID, userID uuid.UUID) (domain.OrgRole, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationMember, error)
	ListWithProfilesByOrganization(ctx context.Context, orgID uuid.UUID) ([]MemberWithProfile, error)
}

type MemberWithProfile struct {
	Member    domain.OrganizationMember
	Name      string
	LastName  string
	Email     string
	AvatarURL *string
}

type InviteRepository interface {
	Create(ctx context.Context, invite *domain.Invite) error
	FindByCode(ctx context.Context, code string) (*domain.Invite, error)
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Invite, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Invite, error)
	IncrementUsed(ctx context.Context, id uuid.UUID) error
	Revoke(ctx context.Context, id uuid.UUID, at time.Time) error
}

type InviteCodeGenerator interface {
	Generate() (string, error)
}

type PersonalOrgCreator interface {
	CreatePersonal(ctx context.Context, ownerID uuid.UUID, ownerName string) (*domain.Organization, error)
}

type EventRepository interface {
	Create(ctx context.Context, event *domain.Event) error
	Update(ctx context.Context, event *domain.Event) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Event, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Event, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

type CategoryRepository interface {
	Create(ctx context.Context, category *domain.Category) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Category, error)
	FindByName(ctx context.Context, orgID uuid.UUID, name string) (*domain.Category, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Category, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

type ActivityRepository interface {
	Append(ctx context.Context, entry *domain.ActivityEntry) error
	ListByOrganization(ctx context.Context, orgID uuid.UUID, limit int) ([]domain.ActivityEntry, error)
}
