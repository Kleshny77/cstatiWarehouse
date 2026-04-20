package httpapi

import (
	"net/http"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type RouterDeps struct {
	Auth          *AuthHandler
	Warehouse     *WarehouseHandler
	Organizations *OrganizationHandler
	Uploads       *UploadsHandler
	Tokens        usecase.TokenIssuer
}

// NewRouter собирает net/http ServeMux поверх входных хендлеров.
// Публичные маршруты идут через общий chain (recover + logging),
// приватные дополнительно через authMiddleware.
func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Auth (public)
	mux.HandleFunc("POST /auth/register", deps.Auth.Register)
	mux.HandleFunc("POST /auth/login", deps.Auth.Login)
	mux.HandleFunc("POST /auth/telegram", deps.Auth.Telegram)
	mux.HandleFunc("POST /auth/refresh", deps.Auth.Refresh)
	mux.HandleFunc("POST /auth/logout", deps.Auth.Logout)

	// Authenticated
	auth := authMiddleware(deps.Tokens)
	mux.Handle("GET /auth/me", auth(http.HandlerFunc(deps.Auth.Me)))
	mux.Handle("PATCH /auth/me", auth(http.HandlerFunc(deps.Auth.UpdateProfile)))

	mux.Handle("GET /items", auth(http.HandlerFunc(deps.Warehouse.List)))
	mux.Handle("POST /items", auth(http.HandlerFunc(deps.Warehouse.Create)))
	mux.Handle("PUT /items/{id}", auth(http.HandlerFunc(deps.Warehouse.Update)))
	mux.Handle("POST /items/{id}/archive", auth(http.HandlerFunc(deps.Warehouse.Archive)))
	mux.Handle("DELETE /items/{id}", auth(http.HandlerFunc(deps.Warehouse.Delete)))
	mux.Handle("GET /categories", auth(http.HandlerFunc(deps.Warehouse.Categories)))
	mux.Handle("GET /archive-events", auth(http.HandlerFunc(deps.Warehouse.ArchiveEvents)))

	mux.Handle("GET /organizations", auth(http.HandlerFunc(deps.Organizations.List)))
	mux.Handle("POST /organizations", auth(http.HandlerFunc(deps.Organizations.Create)))
	mux.Handle("GET /organizations/{id}", auth(http.HandlerFunc(deps.Organizations.Get)))
	mux.Handle("PATCH /organizations/{id}", auth(http.HandlerFunc(deps.Organizations.Update)))
	mux.Handle("DELETE /organizations/{id}", auth(http.HandlerFunc(deps.Organizations.Delete)))
	mux.Handle("GET /organizations/{id}/members", auth(http.HandlerFunc(deps.Organizations.Members)))
	mux.Handle("POST /organizations/{id}/leave", auth(http.HandlerFunc(deps.Organizations.Leave)))

	// Uploads: загрузка — за auth, выдача — публичный static (URL и так непредсказуемый).
	if deps.Uploads != nil {
		mux.Handle("POST /uploads", auth(http.HandlerFunc(deps.Uploads.Upload)))
		mux.Handle("GET /uploads/", deps.Uploads.Static())
	}

	return recoverMiddleware(loggingMiddleware(mux))
}
