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
	if patch.LastName != nil {
		u.LastName = *patch.LastName
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

func (r *fakeItemRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.Item
	for _, i := range r.items {
		if i.OrganizationID != orgID {
			continue
		}
		if filter.Status != nil && i.Status != *filter.Status {
			continue
		}
		if filter.HeldByUserID != nil && i.HeldByUserID != *filter.HeldByUserID {
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

func (r *fakeItemRepo) ListArchiveEvents(ctx context.Context, orgID uuid.UUID) ([]domain.ArchiveEvent, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.ArchiveEvent
	for _, e := range r.events {
		if e.OrganizationID == orgID {
			ev := e
			if item, ok := r.items[e.ItemID]; ok {
				ev.ItemName = item.Name
			}
			out = append(out, ev)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ArchivedAt.After(out[j].ArchivedAt) })
	return out, nil
}

func (r *fakeItemRepo) ListCategoriesByOrganization(ctx context.Context, orgID uuid.UUID) ([]string, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	seen := map[string]struct{}{}
	for _, i := range r.items {
		if i.OrganizationID != orgID {
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

// MARK: OrganizationRepository

type fakeOrgRepo struct {
	mu      sync.Mutex
	orgs    map[uuid.UUID]*domain.Organization
	members *fakeMemberRepo
}

func newFakeOrgRepo(members *fakeMemberRepo) *fakeOrgRepo {
	return &fakeOrgRepo{
		orgs:    map[uuid.UUID]*domain.Organization{},
		members: members,
	}
}

func (r *fakeOrgRepo) Create(ctx context.Context, org *domain.Organization) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *org
	r.orgs[org.ID] = &clone
	return nil
}

func (r *fakeOrgRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	o, ok := r.orgs[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *o
	return &clone, nil
}

func (r *fakeOrgRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]OrganizationWithRole, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []OrganizationWithRole
	for _, o := range r.orgs {
		role, err := r.members.FindRole(ctx, o.ID, userID)
		if err != nil {
			continue
		}
		out = append(out, OrganizationWithRole{Organization: *o, Role: role})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Organization.IsPersonal != out[j].Organization.IsPersonal {
			return out[i].Organization.IsPersonal
		}
		return out[i].Organization.CreatedAt.Before(out[j].Organization.CreatedAt)
	})
	return out, nil
}

func (r *fakeOrgRepo) Update(ctx context.Context, id uuid.UUID, patch OrganizationPatch, now time.Time) (*domain.Organization, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	o, ok := r.orgs[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	if patch.Name != nil {
		o.Name = *patch.Name
	}
	o.UpdatedAt = now
	clone := *o
	return &clone, nil
}

func (r *fakeOrgRepo) SetOwner(ctx context.Context, id, newOwnerID uuid.UUID, now time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	o, ok := r.orgs[id]
	if !ok {
		return domain.ErrNotFound
	}
	o.OwnerID = newOwnerID
	o.UpdatedAt = now
	return nil
}

func (r *fakeOrgRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.orgs[id]; !ok {
		return domain.ErrNotFound
	}
	delete(r.orgs, id)
	return nil
}

func (r *fakeOrgRepo) TransferOwnershipAtomic(ctx context.Context, orgID, fromID, toID uuid.UUID, now time.Time) error {
	if err := r.members.UpdateRole(ctx, orgID, toID, domain.OrgRoleOwner); err != nil {
		return err
	}
	if err := r.members.UpdateRole(ctx, orgID, fromID, domain.OrgRoleAdmin); err != nil {
		return err
	}
	return r.SetOwner(ctx, orgID, toID, now)
}

// MARK: OrganizationMemberRepository

type memberKey struct {
	org  uuid.UUID
	user uuid.UUID
}

type fakeMemberRepo struct {
	mu      sync.Mutex
	members map[memberKey]domain.OrganizationMember
}

func newFakeMemberRepo() *fakeMemberRepo {
	return &fakeMemberRepo{members: map[memberKey]domain.OrganizationMember{}}
}

func (r *fakeMemberRepo) Add(ctx context.Context, m *domain.OrganizationMember) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := memberKey{org: m.OrganizationID, user: m.UserID}
	if _, ok := r.members[key]; ok {
		return domain.ErrAlreadyMember
	}
	r.members[key] = *m
	return nil
}

func (r *fakeMemberRepo) Remove(ctx context.Context, orgID, userID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := memberKey{org: orgID, user: userID}
	if _, ok := r.members[key]; !ok {
		return domain.ErrNotFound
	}
	delete(r.members, key)
	return nil
}

func (r *fakeMemberRepo) UpdateRole(ctx context.Context, orgID, userID uuid.UUID, role domain.OrgRole) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := memberKey{org: orgID, user: userID}
	m, ok := r.members[key]
	if !ok {
		return domain.ErrNotFound
	}
	m.Role = role
	r.members[key] = m
	return nil
}

func (r *fakeMemberRepo) FindRole(ctx context.Context, orgID, userID uuid.UUID) (domain.OrgRole, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := memberKey{org: orgID, user: userID}
	m, ok := r.members[key]
	if !ok {
		return "", domain.ErrNotFound
	}
	return m.Role, nil
}

func (r *fakeMemberRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationMember, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.OrganizationMember
	for _, m := range r.members {
		if m.OrganizationID == orgID {
			out = append(out, m)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].JoinedAt.Before(out[j].JoinedAt) })
	return out, nil
}

func (r *fakeMemberRepo) ListWithProfilesByOrganization(ctx context.Context, orgID uuid.UUID) ([]MemberWithProfile, error) {
	members, err := r.ListByOrganization(ctx, orgID)
	if err != nil {
		return nil, err
	}
	out := make([]MemberWithProfile, 0, len(members))
	for _, m := range members {
		out = append(out, MemberWithProfile{
			Member: m,
			Name:   m.UserID.String(),
			Email:  m.UserID.String() + "@example.com",
		})
	}
	return out, nil
}

// MARK: InviteRepository + generator

type fakeInviteRepo struct {
	mu      sync.Mutex
	invites map[uuid.UUID]*domain.Invite
}

func newFakeInviteRepo() *fakeInviteRepo {
	return &fakeInviteRepo{invites: map[uuid.UUID]*domain.Invite{}}
}

func (r *fakeInviteRepo) Create(ctx context.Context, invite *domain.Invite) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *invite
	r.invites[invite.ID] = &clone
	return nil
}

func (r *fakeInviteRepo) FindByCode(ctx context.Context, code string) (*domain.Invite, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, inv := range r.invites {
		if inv.Code == code {
			clone := *inv
			return &clone, nil
		}
	}
	return nil, domain.ErrNotFound
}

func (r *fakeInviteRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Invite, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	inv, ok := r.invites[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *inv
	return &clone, nil
}

func (r *fakeInviteRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Invite, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.Invite
	for _, inv := range r.invites {
		if inv.OrganizationID == orgID {
			out = append(out, *inv)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (r *fakeInviteRepo) IncrementUsed(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	inv, ok := r.invites[id]
	if !ok {
		return domain.ErrNotFound
	}
	inv.UsedCount++
	return nil
}

func (r *fakeInviteRepo) Revoke(ctx context.Context, id uuid.UUID, at time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	inv, ok := r.invites[id]
	if !ok {
		return domain.ErrNotFound
	}
	if inv.RevokedAt != nil {
		return domain.ErrNotFound
	}
	inv.RevokedAt = &at
	return nil
}

type fakeInviteGen struct {
	mu      sync.Mutex
	counter int
}

func newFakeInviteGen() *fakeInviteGen { return &fakeInviteGen{} }

func (g *fakeInviteGen) Generate() (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.counter++
	return "CODE" + strconv.Itoa(g.counter), nil
}

// MARK: EventRepository

type fakeEventRepo struct {
	mu     sync.Mutex
	events map[uuid.UUID]*domain.Event
}

func newFakeEventRepo() *fakeEventRepo {
	return &fakeEventRepo{events: map[uuid.UUID]*domain.Event{}}
}

func (r *fakeEventRepo) Create(ctx context.Context, e *domain.Event) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *e
	r.events[e.ID] = &clone
	return nil
}

func (r *fakeEventRepo) Update(ctx context.Context, e *domain.Event) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.events[e.ID]; !ok {
		return domain.ErrNotFound
	}
	clone := *e
	r.events[e.ID] = &clone
	return nil
}

func (r *fakeEventRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Event, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	e, ok := r.events[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *e
	return &clone, nil
}

func (r *fakeEventRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Event, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.Event
	for _, e := range r.events {
		if e.OrganizationID == orgID {
			out = append(out, *e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (r *fakeEventRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.events[id]; !ok {
		return domain.ErrNotFound
	}
	delete(r.events, id)
	return nil
}

// MARK: CategoryRepository

type fakeCategoryRepo struct {
	mu    sync.Mutex
	cats  map[uuid.UUID]*domain.Category
}

func newFakeCategoryRepo() *fakeCategoryRepo {
	return &fakeCategoryRepo{cats: map[uuid.UUID]*domain.Category{}}
}

func (r *fakeCategoryRepo) Create(ctx context.Context, c *domain.Category) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, existing := range r.cats {
		if existing.OrganizationID == c.OrganizationID && existing.Name == c.Name {
			return domain.ErrConflict
		}
	}
	clone := *c
	r.cats[c.ID] = &clone
	return nil
}

func (r *fakeCategoryRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Category, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	c, ok := r.cats[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	clone := *c
	return &clone, nil
}

func (r *fakeCategoryRepo) FindByName(ctx context.Context, orgID uuid.UUID, name string) (*domain.Category, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, c := range r.cats {
		if c.OrganizationID == orgID && c.Name == name {
			clone := *c
			return &clone, nil
		}
	}
	return nil, domain.ErrNotFound
}

func (r *fakeCategoryRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Category, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.Category
	for _, c := range r.cats {
		if c.OrganizationID == orgID {
			out = append(out, *c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out, nil
}

func (r *fakeCategoryRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.cats[id]; !ok {
		return domain.ErrNotFound
	}
	delete(r.cats, id)
	return nil
}

// MARK: ActivityRepository

type fakeActivityRepo struct {
	mu      sync.Mutex
	entries []domain.ActivityEntry
}

func newFakeActivityRepo() *fakeActivityRepo {
	return &fakeActivityRepo{}
}

func (r *fakeActivityRepo) Append(ctx context.Context, e *domain.ActivityEntry) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.entries = append(r.entries, *e)
	return nil
}

func (r *fakeActivityRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID, limit int) ([]domain.ActivityEntry, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.ActivityEntry
	for _, e := range r.entries {
		if e.OrganizationID == orgID {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// MARK: PersonalOrgCreator

// fakePersonalOrg реализует узкий порт PersonalOrgCreator.
// В тестах заодно отражает данные в общих fake-репозиториях,
// чтобы после регистрации у пользователя реально было членство.
type fakePersonalOrg struct {
	orgs    *fakeOrgRepo
	members *fakeMemberRepo
	clock   *fakeClock
}

func (f *fakePersonalOrg) CreatePersonal(ctx context.Context, ownerID uuid.UUID, ownerName string) (*domain.Organization, error) {
	now := f.clock.Now()
	org := &domain.Organization{
		ID:         uuid.New(),
		Name:       personalOrgName(ownerName),
		OwnerID:    ownerID,
		IsPersonal: true,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if err := f.orgs.Create(ctx, org); err != nil {
		return nil, err
	}
	if err := f.members.Add(ctx, &domain.OrganizationMember{
		OrganizationID: org.ID,
		UserID:         ownerID,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       now,
	}); err != nil {
		return nil, err
	}
	return org, nil
}
