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

	authUC := usecase.NewAuthUseCase(
		repo.NewUserRepo(pool),
		repo.NewRefreshTokenRepo(pool),
		hasher, issuer, refreshGen, nil, clock.Real{},
		usecase.AuthConfig{RefreshTTL: time.Hour, TelegramConfigured: false},
	)
	warehouseUC := usecase.NewWarehouseUseCase(repo.NewItemRepo(pool), clock.Real{})

	handler := httpapi.NewRouter(httpapi.RouterDeps{
		Auth:      httpapi.NewAuthHandler(authUC),
		Warehouse: httpapi.NewWarehouseHandler(warehouseUC),
		Tokens:    issuer,
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

	status, body := s.do("POST", "/items", bearer(access), map[string]any{
		"name": "Кола", "description": "0.5л", "category_name": "Напитки", "quantity": 3,
	})
	if status != http.StatusCreated {
		t.Fatalf("create item failed: %d %+v", status, body)
	}
	item, _ := body["item"].(map[string]any)
	itemID, _ := item["id"].(string)
	if itemID == "" {
		t.Fatalf("created item missing id: %+v", body)
	}

	status, body = s.do("GET", "/items", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("list failed: %d %+v", status, body)
	}
	items, _ := body["items"].([]any)
	if len(items) != 1 {
		t.Errorf("expected 1 item, got %d", len(items))
	}

	status, body = s.do("GET", "/items?status=in_stock", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 1 {
		t.Errorf("in_stock filter failed: %d %+v", status, body)
	}

	status, body = s.do("GET", "/items?status=archived", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 0 {
		t.Errorf("archived filter failed: %d %+v", status, body)
	}

	status, body = s.do("GET", "/items?status=bogus", bearer(access), nil)
	if status != http.StatusUnprocessableEntity {
		t.Errorf("bogus filter must return 422, got %d %+v", status, body)
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

	status, body = s.do("GET", "/items?status=archived", bearer(access), nil)
	if status != http.StatusOK || len(body["items"].([]any)) != 1 {
		t.Errorf("archived list must now contain 1 item, got %d %+v", status, body)
	}

	status, body = s.do("GET", "/archive-events", bearer(access), nil)
	if status != http.StatusOK {
		t.Fatalf("archive-events failed: %d %+v", status, body)
	}
	events, _ := body["events"].([]any)
	if len(events) != 2 {
		t.Errorf("expected 2 archive events, got %d", len(events))
	}

	status, body = s.do("GET", "/categories", bearer(access), nil)
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

func TestIntegrationHTTP_IsolationBetweenUsers(t *testing.T) {
	s := newTestServer(t)

	a := s.registerUser("a@example.com", "A", "supersecret")
	b := s.registerUser("b@example.com", "B", "supersecret")
	accessA, _ := a["access_token"].(string)
	accessB, _ := b["access_token"].(string)

	status, body := s.do("POST", "/items", bearer(accessA), map[string]any{
		"name": "A-secret", "category_name": "A-cat", "quantity": 1,
	})
	if status != http.StatusCreated {
		t.Fatalf("A create failed: %d %+v", status, body)
	}
	aItemID := body["item"].(map[string]any)["id"].(string)

	status, body = s.do("GET", "/items", bearer(accessB), nil)
	if status != http.StatusOK {
		t.Fatalf("B list failed: %d %+v", status, body)
	}
	if len(body["items"].([]any)) != 0 {
		t.Errorf("B must not see A items: %+v", body)
	}

	status, _ = s.do("DELETE", "/items/"+aItemID, bearer(accessB), nil)
	if status != http.StatusNotFound {
		t.Errorf("B deleting A item must return 404, got %d", status)
	}
}
