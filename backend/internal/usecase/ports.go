package usecase

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// Clock абстрагирует time.Now, чтобы в тестах его можно было контролировать.
type Clock interface {
	Now() time.Time
}

// PasswordHasher прячет реализацию (bcrypt) за портом.
type PasswordHasher interface {
	Hash(password string) (string, error)
	Verify(hash, password string) error
}

// TokenIssuer выпускает и валидирует наши access-токены (HS256).
type TokenIssuer interface {
	IssueAccessToken(userID uuid.UUID, issuedAt time.Time) (token string, expiresAt time.Time, err error)
	ParseAccessToken(token string) (userID uuid.UUID, err error)
}

// RefreshTokenGenerator возвращает пару (plaintext, hash). Plaintext отдаётся клиенту,
// hash сохраняется в БД.
type RefreshTokenGenerator interface {
	Generate() (plaintext string, hash string, err error)
	Hash(plaintext string) string
}

// TelegramVerifier проверяет id_token от Telegram и возвращает claims.
type TelegramVerifier interface {
	Verify(ctx context.Context, idToken string) (domain.TelegramClaims, error)
}

// UserProfileUpdate — патч к публичному профилю пользователя.
// Поле == nil означает "не менять".
type UserProfileUpdate struct {
	Name      *string
	AvatarURL *string
}

// UserRepository — порт для чтения/записи пользователей.
type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*domain.User, error)
	FindByTelegramSub(ctx context.Context, sub string) (*domain.User, error)
	UpdateProfile(ctx context.Context, id uuid.UUID, patch UserProfileUpdate, now time.Time) (*domain.User, error)
}

// RefreshTokenRepository хранит выданные refresh-токены (в виде хэшей).
type RefreshTokenRepository interface {
	Create(ctx context.Context, token *domain.RefreshToken) error
	FindByHash(ctx context.Context, hash string) (*domain.RefreshToken, error)
	Revoke(ctx context.Context, hash string, at time.Time) error
}

// ItemFilter позволяет ограничить выдачу ListByOrganization по статусу.
// Nil статус означает "любой".
type ItemFilter struct {
	Status *domain.ItemStatus
}

// ItemRepository — CRUD позиций склада. Все операции работают в scope одной организации.
type ItemRepository interface {
	Create(ctx context.Context, item *domain.Item) error
	Update(ctx context.Context, item *domain.Item) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Item, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error)
	Delete(ctx context.Context, id uuid.UUID) error
	ListCategoriesByOrganization(ctx context.Context, orgID uuid.UUID) ([]string, error)
	// RecordArchiveEvent обновляет item (quantity/status) и пишет событие списания в одной транзакции.
	RecordArchiveEvent(ctx context.Context, item *domain.Item, event *domain.ArchiveEvent) error
	ListArchiveEvents(ctx context.Context, orgID uuid.UUID) ([]domain.ArchiveEvent, error)
}

// OrganizationPatch — частичное обновление организации.
// Поле == nil означает "не менять".
type OrganizationPatch struct {
	Name *string
}

// OrganizationRepository — CRUD организаций и выборка по участнику.
type OrganizationRepository interface {
	Create(ctx context.Context, org *domain.Organization) error
	FindByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error)
	// ListByUser возвращает организации, в которых состоит пользователь, вместе с его ролью в каждой.
	ListByUser(ctx context.Context, userID uuid.UUID) ([]OrganizationWithRole, error)
	Update(ctx context.Context, id uuid.UUID, patch OrganizationPatch, now time.Time) (*domain.Organization, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

// OrganizationWithRole — организация + роль текущего пользователя в ней.
// Используется для экрана "мои организации" и для быстрых авторизационных проверок.
type OrganizationWithRole struct {
	Organization domain.Organization
	Role         domain.OrgRole
}

// OrganizationMemberRepository управляет участниками организации.
type OrganizationMemberRepository interface {
	Add(ctx context.Context, member *domain.OrganizationMember) error
	Remove(ctx context.Context, orgID, userID uuid.UUID) error
	UpdateRole(ctx context.Context, orgID, userID uuid.UUID, role domain.OrgRole) error
	FindRole(ctx context.Context, orgID, userID uuid.UUID) (domain.OrgRole, error)
	ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationMember, error)
}

// PersonalOrgCreator — узкий порт, который Auth использует для создания персональной
// организации при регистрации нового пользователя. Реализуется OrganizationsUseCase.
type PersonalOrgCreator interface {
	CreatePersonal(ctx context.Context, ownerID uuid.UUID, ownerName string) (*domain.Organization, error)
}
