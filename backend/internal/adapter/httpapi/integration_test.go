//go:build integration

package httpapi_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/httpapi"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/clock"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/invitecode"
	infrajwt "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/password"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/testsupport"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type testServer struct {
	t    *testing.T
	http *httptest.Server
}

func newTestServer(t *testing.T) *testServer {
	t.Helper()
	pool := testsupport.SetupDB(t)

	issuer := infrajwt.NewIssuer("integration-test-secret-that-is-long-enough", 15*time.Minute)
	refreshGen := infrajwt.NewRefreshGenerator()
	hasher := password.NewBcryptHasher(4)

	orgsRepo := repo.NewOrganizationRepo(pool)
	membersRepo := repo.NewMemberRepo(pool)
	invitesRepo := repo.NewInviteRepo(pool)
	eventsRepo := repo.NewEventRepo(pool)
	categoriesRepo := repo.NewCategoryRepo(pool)
	activityRepo := repo.NewActivityRepo(pool)
	itemsRepo := repo.NewItemRepo(pool)
	inviteGen := invitecode.NewGenerator(8)
	orgsUC := usecase.NewOrganizationsUseCase(orgsRepo, membersRepo, invitesRepo, inviteGen, clock.Real{}).
		WithActivity(activityRepo)

	authUC := usecase.NewAuthUseCase(
		repo.NewUserRepo(pool),
		repo.NewRefreshTokenRepo(pool),
		orgsUC,
		hasher, issuer, refreshGen, nil, clock.Real{},
		usecase.AuthConfig{RefreshTTL: time.Hour, TelegramConfigured: false},
	)
	warehouseUC := usecase.NewWarehouseUseCase(itemsRepo, membersRepo, clock.Real{}).
		WithActivity(activityRepo).
		WithEvents(eventsRepo)
	eventsUC := usecase.NewEventsUseCase(eventsRepo, membersRepo, activityRepo, clock.Real{})
	categoriesUC := usecase.NewCategoriesUseCase(categoriesRepo, membersRepo, activityRepo, clock.Real{})
	activityUC := usecase.NewActivityUseCase(activityRepo, membersRepo)

	handler := httpapi.NewRouter(httpapi.RouterDeps{
		Auth:          httpapi.NewAuthHandler(authUC),
		Warehouse:     httpapi.NewWarehouseHandler(warehouseUC),
		Organizations: httpapi.NewOrganizationHandler(orgsUC),
		Events:        httpapi.NewEventsHandler(eventsUC),
		Categories:    httpapi.NewCategoriesHandler(categoriesUC),
		Activity:      httpapi.NewActivityHandler(activityUC),
		Tokens:        issuer,
	})

	s := httptest.NewServer(handler)
	t.Cleanup(s.Close)
	return &testServer{t: t, http: s}
}

func (s *testServer) do(method, path string, headers map[string]string, body any) (int, map[string]any) {
	s.t.Helper()

	var bodyReader io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			s.t.Fatalf("marshal body: %v", err)
		}
		bodyReader = bytes.NewReader(buf)
	}
	req, err := http.NewRequest(method, s.http.URL+path, bodyReader)
	if err != nil {
		s.t.Fatalf("new request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := s.http.Client().Do(req)
	if err != nil {
		s.t.Fatalf("do request: %v", err)
	}
	defer resp.Body.Close()

	var out map[string]any
	if resp.ContentLength != 0 {
		raw, err := io.ReadAll(resp.Body)
		if err != nil {
			s.t.Fatalf("read body: %v", err)
		}
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &out); err != nil {
				s.t.Fatalf("unmarshal body (status %d): %v; raw=%s", resp.StatusCode, err, string(raw))
			}
		}
	}
	return resp.StatusCode, out
}

func (s *testServer) registerUser(email, name, password string) map[string]any {
	status, body := s.do("POST", "/auth/register", nil, map[string]string{
		"email": email, "name": name, "password": password,
	})
	if status != http.StatusCreated {
		s.t.Fatalf("register %s failed: status=%d body=%+v", email, status, body)
	}
	return body
}

// personalOrgID берёт id персональной организации пользователя через /organizations.
// Она автоматически создаётся при регистрации.
func (s *testServer) personalOrgID(access string) string {
	s.t.Helper()
	status, body := s.do("GET", "/organizations", bearer(access), nil)
	if status != http.StatusOK {
		s.t.Fatalf("list orgs failed: %d %+v", status, body)
	}
	orgs, _ := body["organizations"].([]any)
	for _, raw := range orgs {
		o, _ := raw.(map[string]any)
		if personal, _ := o["is_personal"].(bool); personal {
			id, _ := o["id"].(string)
			return id
		}
	}
	s.t.Fatalf("personal organization not found in %+v", body)
	return ""
}

func bearer(token string) map[string]string {
	return map[string]string{"Authorization": "Bearer " + token}
}

func TestIntegrationHTTP_RegisterLoginMe(t *testing.T) {
	s := newTestServer(t)

	reg := s.registerUser("alice@example.com", "Alice", "supersecret")
	access, _ := reg["access_token"].(string)
	if access == "" {
		t.Fatal("access_token missing")
	}

	status, body := s.do("GET", "/auth/me", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("me failed: %d %+v", status, body)
	}
	if body["email"] != "alice@example.com" {
		t.Errorf("unexpected /me body: %+v", body)
	}

	// Персональная организация должна автоматически появиться при регистрации.
	status, body = s.do("GET", "/organizations", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("list orgs failed: %d %+v", status, body)
	}
	orgs, _ := body["organizations"].([]any)
	if len(orgs) != 1 {
		t.Errorf("expected 1 personal organization after register, got %+v", body)
	}

	status, body = s.do("POST", "/auth/login", nil, map[string]string{
		"email": "alice@example.com", "password": "supersecret",
	})
	if status != http.StatusOK {
		t.Fatalf("login failed: %d %+v", status, body)
	}

	status, body = s.do("POST", "/auth/login", nil, map[string]string{
		"email": "alice@example.com", "password": "wrong",
	})
	if status != http.StatusUnauthorized {
		t.Errorf("wrong password must return 401, got %d %+v", status, body)
	}
}

func TestIntegrationHTTP_WarehouseCRUD(t *testing.T) {
	s := newTestServer(t)
	reg := s.registerUser("warehouse@example.com", "W", "supersecret")
	access, _ := reg["access_token"].(string)
	orgID := s.personalOrgID(access)

	status, body := s.do("POST", "/items", bearer(access), map[string]any{
		"organization_id": orgID,
		"name":            "Кола",
		"description":     "0.5л",
		"category_name":   "Напитки",
		"quantity":        3,
	})
	if status != http.StatusCreated {
		t.Fatalf("create item failed: %d %+v", status, body)
	}
	item, _ := body["item"].(map[string]any)
	itemID, _ := item["id"].(string)
	if itemID == "" {
		t.Fatalf("created item missing id: %+v", body)
	}

	orgQuery := "?organizationId=" + orgID

	status, body = s.do("GET", "/items"+orgQuery, bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("list failed: %d %+v", status, body)
	}
	items, _ := body["items"].([]any)
	if len(items) != 1 {
		t.Errorf("expected 1 item, got %d", len(items))
	}

	status, body = s.do("GET", "/items"+orgQuery+"&status=in_stock", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 1 {
		t.Errorf("in_stock filter failed: %d %+v", status, body)
	}

	status, body = s.do("GET", "/items"+orgQuery+"&status=archived", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 0 {
		t.Errorf("archived filter failed: %d %+v", status, body)
	}

	status, body = s.do("GET", "/items"+orgQuery+"&status=bogus", bearer(access), nil)
	if status != http.StatusUnprocessableEntity {
		t.Errorf("bogus filter must return 422, got %d %+v", status, body)
	}

	// Без organizationId — ошибка валидации.
	status, _ = s.do("GET", "/items", bearer(access), nil)
	if status != http.StatusUnprocessableEntity {
		t.Errorf("missing organizationId must return 422, got %d", status)
	}

	status, body = s.do("POST", fmt.Sprintf("/items/%s/archive", itemID), bearer(access), map[string]any{
		"quantity":      1,
		"reason":        "usedAtEvent",
		"reason_detail": "Хакатон",
	})
	if status != http.StatusOK {
		t.Fatalf("archive failed: %d %+v", status, body)
	}
	archivedItem, _ := body["item"].(map[string]any)
	if q, _ := archivedItem["quantity"].(float64); q != 2 {
		t.Errorf("expected remaining quantity 2 after partial archive, got %v", archivedItem["quantity"])
	}

	status, body = s.do("POST", fmt.Sprintf("/items/%s/archive", itemID), bearer(access), map[string]any{
		"quantity": 2,
		"reason":   "disposed",
	})
	if status != http.StatusOK {
		t.Fatalf("full archive failed: %d %+v", status, body)
	}

	status, body = s.do("GET", "/items"+orgQuery+"&status=archived", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 1 {
		t.Errorf("archived list must now contain 1 item, got %d %+v", status, body)
	}

	status, body = s.do("GET", "/archive-events"+orgQuery, bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("archive-events failed: %d %+v", status, body)
	}
	events, _ := body["events"].([]any)
	if len(events) != 2 {
		t.Errorf("expected 2 archive events, got %d", len(events))
	}

	status, body = s.do("GET", "/categories"+orgQuery, bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("categories failed: %d %+v", status, body)
	}
	cats, _ := body["categories"].([]any)
	if len(cats) != 1 || cats[0] != "Напитки" {
		t.Errorf("unexpected categories: %+v", cats)
	}

	status, _ = s.do("DELETE", "/items/"+itemID, bearer(access), nil)
	if status != http.StatusNoContent {
		t.Errorf("delete failed: %d", status)
	}
}

func TestIntegrationHTTP_RefreshRotation(t *testing.T) {
	s := newTestServer(t)
	reg := s.registerUser("refresh@example.com", "R", "supersecret")
	refresh, _ := reg["refresh_token"].(string)

	status, body := s.do("POST", "/auth/refresh", nil, map[string]string{"refresh_token": refresh})
	if status != http.StatusOK {
		t.Fatalf("refresh failed: %d %+v", status, body)
	}
	newRefresh, _ := body["refresh_token"].(string)
	if newRefresh == refresh || newRefresh == "" {
		t.Errorf("refresh must be rotated, new=%q old=%q", newRefresh, refresh)
	}

	status, body = s.do("POST", "/auth/refresh", nil, map[string]string{"refresh_token": refresh})
	if status != http.StatusUnauthorized {
		t.Errorf("old refresh must be invalid, got %d %+v", status, body)
	}
}

func TestIntegrationHTTP_TelegramDisabled(t *testing.T) {
	s := newTestServer(t)
	status, body := s.do("POST", "/auth/telegram", nil, map[string]string{"id_token": "whatever"})
	if status != http.StatusServiceUnavailable {
		t.Errorf("telegram disabled must return 503, got %d %+v", status, body)
	}
}

func TestIntegrationHTTP_IsolationBetweenOrgs(t *testing.T) {
	s := newTestServer(t)

	a := s.registerUser("a@example.com", "A", "supersecret")
	b := s.registerUser("b@example.com", "B", "supersecret")
	accessA, _ := a["access_token"].(string)
	accessB, _ := b["access_token"].(string)
	orgA := s.personalOrgID(accessA)
	orgB := s.personalOrgID(accessB)

	status, body := s.do("POST", "/items", bearer(accessA), map[string]any{
		"organization_id": orgA,
		"name":            "A-secret",
		"category_name":   "A-cat",
		"quantity":        1,
	})
	if status != http.StatusCreated {
		t.Fatalf("A create failed: %d %+v", status, body)
	}
	aItemID := body["item"].(map[string]any)["id"].(string)

	// B в своей организации не видит айтемы A.
	status, body = s.do("GET", "/items?organizationId="+orgB, bearer(accessB), nil)
	if status != http.StatusOK {
		t.Fatalf("B list own failed: %d %+v", status, body)
	}
	if len(body["items"].([]any)) != 0 {
		t.Errorf("B must not see A items in own org: %+v", body)
	}

	// B не может запрашивать список по orgA — forbidden.
	status, _ = s.do("GET", "/items?organizationId="+orgA, bearer(accessB), nil)
	if status != http.StatusForbidden {
		t.Errorf("B listing A's org must return 403, got %d", status)
	}

	// B не может удалить айтем в чужой организации — 404 (не раскрываем существование).
	status, _ = s.do("DELETE", "/items/"+aItemID, bearer(accessB), nil)
	if status != http.StatusNotFound {
		t.Errorf("B deleting A item must return 404, got %d", status)
	}
}

func TestIntegrationHTTP_Organizations(t *testing.T) {
	s := newTestServer(t)

	reg := s.registerUser("org-owner@example.com", "Owner", "supersecret")
	access, _ := reg["access_token"].(string)
	personal := s.personalOrgID(access)

	// Создание новой организации (не персональной).
	status, body := s.do("POST", "/organizations", bearer(access), map[string]any{"name": "Команда"})
	if status != http.StatusCreated {
		t.Fatalf("create org failed: %d %+v", status, body)
	}
	org, _ := body["organization"].(map[string]any)
	orgID, _ := org["id"].(string)
	if orgID == "" || org["is_personal"] != false {
		t.Errorf("unexpected created org: %+v", body)
	}

	// Listing: должны быть 2 организации (personal + команда).
	status, body = s.do("GET", "/organizations", bearer(access), nil)
	if status != http.StatusOK || len(body["organizations"].([]any)) != 2 {
		t.Errorf("expected 2 orgs, got %d %+v", status, body)
	}

	// Owner — единственный участник созданной org.
	status, body = s.do("GET", "/organizations/"+orgID+"/members", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("list members failed: %d %+v", status, body)
	}
	mems, _ := body["members"].([]any)
	if len(mems) != 1 {
		t.Errorf("expected 1 owner member, got %d", len(mems))
	}

	// Персональную удалить нельзя — 409.
	status, _ = s.do("DELETE", "/organizations/"+personal, bearer(access), nil)
	if status != http.StatusConflict {
		t.Errorf("deleting personal org must return 409, got %d", status)
	}

	// Owner не может выйти из своей org — 409.
	status, _ = s.do("POST", "/organizations/"+orgID+"/leave", bearer(access), nil)
	if status != http.StatusConflict {
		t.Errorf("owner leave must return 409, got %d", status)
	}

	// А обычную — удалить можно.
	status, _ = s.do("DELETE", "/organizations/"+orgID, bearer(access), nil)
	if status != http.StatusNoContent {
		t.Errorf("delete org failed: %d", status)
	}
}

func TestIntegrationHTTP_EventsCategoriesActivity(t *testing.T) {
	s := newTestServer(t)

	reg := s.registerUser("d-owner@example.com", "Dueсу", "supersecret")
	access, _ := reg["access_token"].(string)
	personal := s.personalOrgID(access)

	// Создать категорию.
	status, body := s.do("POST", "/org-categories", bearer(access), map[string]any{
		"organization_id": personal,
		"name":            "Напитки",
	})
	if status != http.StatusCreated {
		t.Fatalf("create category failed: %d %+v", status, body)
	}
	cat, _ := body["category"].(map[string]any)
	catID, _ := cat["id"].(string)

	status, body = s.do("GET", "/org-categories?organizationId="+personal, bearer(access), nil)
	if status != http.StatusOK || len(body["categories"].([]any)) != 1 {
		t.Fatalf("list categories failed: %d %+v", status, body)
	}

	// Дубликат — 409.
	status, _ = s.do("POST", "/org-categories", bearer(access), map[string]any{
		"organization_id": personal,
		"name":            "напитки",
	})
	if status != http.StatusConflict {
		t.Errorf("duplicate category must be 409, got %d", status)
	}

	// Создать event.
	status, body = s.do("POST", "/events", bearer(access), map[string]any{
		"organization_id": personal,
		"name":            "Квиз",
	})
	if status != http.StatusCreated {
		t.Fatalf("create event failed: %d %+v", status, body)
	}
	ev, _ := body["event"].(map[string]any)
	eventID, _ := ev["id"].(string)

	status, body = s.do("GET", "/events?organizationId="+personal, bearer(access), nil)
	if status != http.StatusOK || len(body["events"].([]any)) != 1 {
		t.Fatalf("list events failed: %d %+v", status, body)
	}

	// Создать item и списать на мероприятие по event_id.
	status, body = s.do("POST", "/items", bearer(access), map[string]any{
		"organization_id": personal,
		"name":            "Сок",
		"quantity":        2,
	})
	if status != http.StatusCreated {
		t.Fatalf("create item failed: %d %+v", status, body)
	}
	item, _ := body["item"].(map[string]any)
	itemID, _ := item["id"].(string)

	status, body = s.do("POST", fmt.Sprintf("/items/%s/archive", itemID), bearer(access), map[string]any{
		"quantity": 1,
		"reason":   "usedAtEvent",
		"event_id": eventID,
	})
	if status != http.StatusOK {
		t.Fatalf("archive by event failed: %d %+v", status, body)
	}
	archivedEvent, _ := body["event"].(map[string]any)
	if id, _ := archivedEvent["event_id"].(string); id != eventID {
		t.Errorf("archive event must reference event_id, got %+v", archivedEvent)
	}

	// Activity log должен содержать минимум: category.created, event.created, item.created, item.archived.
	status, body = s.do("GET", "/organizations/"+personal+"/activity", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("activity failed: %d %+v", status, body)
	}
	entries, _ := body["entries"].([]any)
	if len(entries) < 4 {
		t.Errorf("expected at least 4 activity entries, got %d: %+v", len(entries), entries)
	}

	// Удаление категории.
	status, _ = s.do("DELETE", "/org-categories/"+catID, bearer(access), nil)
	if status != http.StatusNoContent {
		t.Errorf("delete category failed: %d", status)
	}

	// Удаление event.
	status, _ = s.do("DELETE", "/events/"+eventID, bearer(access), nil)
	if status != http.StatusNoContent {
		t.Errorf("delete event failed: %d", status)
	}
}
