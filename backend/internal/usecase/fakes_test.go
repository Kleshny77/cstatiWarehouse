package usecase

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// MARK: Clock

type fakeClock struct {
	mu  sync.Mutex
	now time.Time
}

func newFakeClock(t time.Time) *fakeClock { return &fakeClock{now: t} }

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
}

// MARK: PasswordHasher

// Детерминированный «хэшер» для тестов: hash(password) = "hash:" + password,
// проверка сравнивает суффикс.
type fakeHasher struct{}

func (f *fakeHasher) Hash(password string) (string, error) { return "hash:" + password, nil }
func (f *fakeHasher) Verify(hash, password string) error {
	if hash == "hash:"+password {
		return nil
	}
	return errors.New("mismatch")
}

// MARK: TokenIssuer

type fakeTokenIssuer struct {
	ttl time.Duration
}

func (f *fakeTokenIssuer) IssueAccessToken(userID uuid.UUID, issuedAt time.Time) (string, time.Time, error) {
	exp := issuedAt.Add(f.ttl)
	return "access:" + userID.String() + ":" + strconv.FormatInt(issuedAt.UnixNano(), 10), exp, nil
}

func (f *fakeTokenIssuer) ParseAccessToken(token string) (uuid.UUID, error) {
	return uuid.Nil, errors.New("not used in usecase tests")
}

// MARK: RefreshTokenGenerator

type fakeRefreshGen struct {
	counter int
}

func (f *fakeRefreshGen) Generate() (string, string, error) {
	f.counter++
	plaintext := "refresh-" + strconv.Itoa(f.counter)
	return plaintext, f.Hash(plaintext), nil
}

func (f *fakeRefreshGen) Hash(plaintext string) string {
	sum := sha256.Sum256([]byte(plaintext))
	return hex.EncodeToString(sum[:])
}

// MARK: TelegramVerifier

type fakeTelegramVerifier struct {
	result domain.TelegramClaims
	err    error
}

func (f *fakeTelegramVerifier) Verify(ctx context.Context, idToken string) (domain.TelegramClaims, error) {
	if f.err != nil {
		return domain.TelegramClaims{}, f.err
	}
	return f.result, nil
}

// MARK: UserRepository

type fakeUserRepo struct {
	mu    sync.Mutex
	users map[uuid.UUID]*domain.User
}

func newFakeUserRepo() *fakeUserRepo {
	return &fakeUserRepo{users: map[uuid.UUID]*domain.User{}}
}

func (r *fakeUserRepo) Create(ctx context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if u.Email == user.Email {
			return domain.ErrEmailAlreadyUsed
		}
	}
	clone := *user
	r.users[user.ID] = &clone
	return nil
}

func (r *fakeUserRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	u, ok := r.users[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *u
	return &clone, nil
}

func (r *fakeUserRepo) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if u.Email == email {
			clone := *u
			return &clone, nil
		}
	}
	return nil, domain.ErrNotFound
}

func (r *fakeUserRepo) FindByTelegramSub(ctx context.Context, sub string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if u.TelegramSub != nil && *u.TelegramSub == sub {
			clone := *u
			return &clone, nil
		}
	}
	return nil, domain.ErrNotFound
}

func (r *fakeUserRepo) UpdateProfile(ctx context.Context, id uuid.UUID, patch UserProfileUpdate, now time.Time) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	u, ok := r.users[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	if patch.Name != nil {
		u.Name = *patch.Name
	}
	if patch.AvatarURL != nil {
		trimmed := *patch.AvatarURL
		if trimmed == "" {
			u.AvatarURL = nil
		} else {
			v := trimmed
			u.AvatarURL = &v
		}
	}
	u.UpdatedAt = now
	clone := *u
	return &clone, nil
}

// MARK: RefreshTokenRepository

type fakeRefreshRepo struct {
	mu     sync.Mutex
	tokens map[string]*domain.RefreshToken
}

func newFakeRefreshRepo() *fakeRefreshRepo {
	return &fakeRefreshRepo{tokens: map[string]*domain.RefreshToken{}}
}

func (r *fakeRefreshRepo) Create(ctx context.Context, token *domain.RefreshToken) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *token
	r.tokens[token.TokenHash] = &clone
	return nil
}

func (r *fakeRefreshRepo) FindByHash(ctx context.Context, hash string) (*domain.RefreshToken, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	t, ok := r.tokens[hash]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *t
	return &clone, nil
}

func (r *fakeRefreshRepo) Revoke(ctx context.Context, hash string, at time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	t, ok := r.tokens[hash]
	if !ok {
		return domain.ErrNotFound
	}
	t.RevokedAt = &at
	return nil
}

// MARK: ItemRepository

type fakeItemRepo struct {
	mu     sync.Mutex
	items  map[uuid.UUID]*domain.Item
	events []domain.ArchiveEvent
}

func newFakeItemRepo() *fakeItemRepo {
	return &fakeItemRepo{items: map[uuid.UUID]*domain.Item{}}
}

func (r *fakeItemRepo) Create(ctx context.Context, item *domain.Item) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *item
	r.items[item.ID] = &clone
	return nil
}

func (r *fakeItemRepo) Update(ctx context.Context, item *domain.Item) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.items[item.ID]; !ok {
		return domain.ErrNotFound
	}
	clone := *item
	r.items[item.ID] = &clone
	return nil
}

func (r *fakeItemRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Item, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	i, ok := r.items[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *i
	return &clone, nil
}

func (r *fakeItemRepo) ListByOwner(ctx context.Context, ownerID uuid.UUID, filter ItemFilter) ([]domain.Item, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.Item
	for _, i := range r.items {
		if i.OwnerID != ownerID {
			continue
		}
		if filter.Status != nil && i.Status != *filter.Status {
			continue
		}
		out = append(out, *i)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (r *fakeItemRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.items[id]; !ok {
		return domain.ErrNotFound
	}
	delete(r.items, id)
	return nil
}

func (r *fakeItemRepo) RecordArchiveEvent(ctx context.Context, item *domain.Item, event *domain.ArchiveEvent) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.items[item.ID]; !ok {
		return domain.ErrNotFound
	}
	clone := *item
	r.items[item.ID] = &clone
	r.events = append(r.events, *event)
	return nil
}

func (r *fakeItemRepo) ListArchiveEvents(ctx context.Context, ownerID uuid.UUID) ([]domain.ArchiveEvent, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.ArchiveEvent
	for _, e := range r.events {
		if e.OwnerID == ownerID {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ArchivedAt.After(out[j].ArchivedAt) })
	return out, nil
}

func (r *fakeItemRepo) ListCategoriesByOwner(ctx context.Context, ownerID uuid.UUID) ([]string, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	seen := map[string]struct{}{}
	for _, i := range r.items {
		if i.OwnerID != ownerID {
			continue
		}
		if i.CategoryName == "" {
			continue
		}
		seen[i.CategoryName] = struct{}{}
	}
	out := make([]string, 0, len(seen))
	for c := range seen {
		out = append(out, c)
	}
	sort.Strings(out)
	return out, nil
}
