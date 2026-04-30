package httpapi

import (
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/ratelimit"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type RouterDeps struct {
	Auth                    *AuthHandler
	Warehouse               *WarehouseHandler
	Organizations           *OrganizationHandler
	Events                  *EventsHandler
	Categories              *CategoriesHandler
	Activity                *ActivityHandler
	Analytics               *AnalyticsHandler
	Uploads                 *UploadsHandler
	Notifications           *NotificationsHandler
	ExpirationNotifications *ExpirationNotificationsHandler
	Comments                *CommentsHandler
	Reservations            *ReservationsHandler
	WebSocket               *WebSocketHandler
	Tokens                  usecase.TokenIssuer
	ClientIP func(*http.Request) string
	SkipAuthRateLimit bool
	UserLimiter *ratelimit.UserLimiter
	CORSAllowedOrigins []string
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("POST /auth/register", deps.Auth.Register)
	mux.HandleFunc("POST /auth/login", deps.Auth.Login)
	mux.HandleFunc("POST /auth/telegram", deps.Auth.Telegram)
	mux.HandleFunc("POST /auth/google", deps.Auth.Google)
	mux.HandleFunc("POST /auth/refresh", deps.Auth.Refresh)
	mux.HandleFunc("POST /auth/logout", deps.Auth.Logout)

	auth := authMiddleware(deps.Tokens)

	var authWithUserRL func(http.Handler) http.Handler
	if deps.UserLimiter != nil {
		authWithUserRL = func(h http.Handler) http.Handler {
			return auth(userRateLimitMiddleware(deps.UserLimiter)(h))
		}
	} else {
		authWithUserRL = auth
	}

	mux.Handle("GET /auth/me", authWithUserRL(http.HandlerFunc(deps.Auth.Me)))
	mux.Handle("PATCH /auth/me", authWithUserRL(http.HandlerFunc(deps.Auth.UpdateProfile)))

	mux.Handle("GET /items", authWithUserRL(http.HandlerFunc(deps.Warehouse.List)))
	mux.Handle("POST /items", authWithUserRL(http.HandlerFunc(deps.Warehouse.Create)))
	mux.Handle("PUT /items/{id}", authWithUserRL(http.HandlerFunc(deps.Warehouse.Update)))
	mux.Handle("POST /items/{id}/archive", authWithUserRL(http.HandlerFunc(deps.Warehouse.Archive)))
	mux.Handle("DELETE /items/{id}", authWithUserRL(http.HandlerFunc(deps.Warehouse.Delete)))
	mux.Handle("GET /categories", authWithUserRL(http.HandlerFunc(deps.Warehouse.Categories)))
	mux.Handle("GET /archive-events", authWithUserRL(http.HandlerFunc(deps.Warehouse.ArchiveEvents)))

	mux.Handle("GET /organizations", authWithUserRL(http.HandlerFunc(deps.Organizations.List)))
	mux.Handle("POST /organizations", authWithUserRL(http.HandlerFunc(deps.Organizations.Create)))
	mux.Handle("POST /organizations/join", authWithUserRL(http.HandlerFunc(deps.Organizations.JoinByCode)))
	mux.Handle("GET /organizations/{id}", authWithUserRL(http.HandlerFunc(deps.Organizations.Get)))
	mux.Handle("PATCH /organizations/{id}", authWithUserRL(http.HandlerFunc(deps.Organizations.Update)))
	mux.Handle("DELETE /organizations/{id}", authWithUserRL(http.HandlerFunc(deps.Organizations.Delete)))
	mux.Handle("GET /organizations/{id}/members", authWithUserRL(http.HandlerFunc(deps.Organizations.Members)))
	mux.Handle("DELETE /organizations/{id}/members/{userId}", authWithUserRL(http.HandlerFunc(deps.Organizations.RemoveMember)))
	mux.Handle("PATCH /organizations/{id}/members/{userId}", authWithUserRL(http.HandlerFunc(deps.Organizations.ChangeRole)))
	mux.Handle("POST /organizations/{id}/transfer", authWithUserRL(http.HandlerFunc(deps.Organizations.TransferOwnership)))
	mux.Handle("POST /organizations/{id}/leave", authWithUserRL(http.HandlerFunc(deps.Organizations.Leave)))
	mux.Handle("GET /organizations/{id}/invites", authWithUserRL(http.HandlerFunc(deps.Organizations.ListInvites)))
	mux.Handle("POST /organizations/{id}/invites", authWithUserRL(http.HandlerFunc(deps.Organizations.CreateInvite)))
	mux.Handle("DELETE /organizations/{id}/invites/{inviteId}", authWithUserRL(http.HandlerFunc(deps.Organizations.RevokeInvite)))

	if deps.Events != nil {
		mux.Handle("GET /events", authWithUserRL(http.HandlerFunc(deps.Events.List)))
		mux.Handle("POST /events", authWithUserRL(http.HandlerFunc(deps.Events.Create)))
		mux.Handle("PATCH /events/{id}", authWithUserRL(http.HandlerFunc(deps.Events.Update)))
		mux.Handle("DELETE /events/{id}", authWithUserRL(http.HandlerFunc(deps.Events.Delete)))
	}
	if deps.Categories != nil {
		mux.Handle("GET /org-categories", authWithUserRL(http.HandlerFunc(deps.Categories.List)))
		mux.Handle("POST /org-categories", authWithUserRL(http.HandlerFunc(deps.Categories.Create)))
		mux.Handle("DELETE /org-categories/{id}", authWithUserRL(http.HandlerFunc(deps.Categories.Delete)))
	}
	if deps.Activity != nil {
		mux.Handle("GET /organizations/{id}/activity", authWithUserRL(http.HandlerFunc(deps.Activity.List)))
	}
	if deps.Analytics != nil {
		mux.Handle("GET /analytics/dashboard", authWithUserRL(http.HandlerFunc(deps.Analytics.GetDashboard)))
	}

	if deps.Uploads != nil {
		mux.Handle("POST /uploads", authWithUserRL(http.HandlerFunc(deps.Uploads.Upload)))
		mux.Handle("GET /uploads/{file}", http.HandlerFunc(deps.Uploads.Download))
	}
	if deps.Notifications != nil {
		mux.Handle("POST /notifications/apns-token", authWithUserRL(http.HandlerFunc(deps.Notifications.RegisterAPNs)))
	}
	if deps.ExpirationNotifications != nil {
		mux.Handle("GET /notifications/preferences", authWithUserRL(http.HandlerFunc(deps.ExpirationNotifications.GetPreferences)))
		mux.Handle("PUT /notifications/preferences", authWithUserRL(http.HandlerFunc(deps.ExpirationNotifications.UpdatePreferences)))
		mux.Handle("GET /notifications/expiration", authWithUserRL(http.HandlerFunc(deps.ExpirationNotifications.ListRecent)))
		mux.Handle("POST /notifications/expiration/snooze", authWithUserRL(http.HandlerFunc(deps.ExpirationNotifications.Snooze)))
	}
	if deps.Comments != nil {
		mux.Handle("POST /items/{itemID}/comments", authWithUserRL(http.HandlerFunc(deps.Comments.Create)))
		mux.Handle("GET /items/{itemID}/comments", authWithUserRL(http.HandlerFunc(deps.Comments.List)))
		mux.Handle("PUT /comments/{commentID}", authWithUserRL(http.HandlerFunc(deps.Comments.Update)))
		mux.Handle("DELETE /comments/{commentID}", authWithUserRL(http.HandlerFunc(deps.Comments.Delete)))
		mux.Handle("POST /comments/{commentID}/reactions", authWithUserRL(http.HandlerFunc(deps.Comments.AddReaction)))
		mux.Handle("DELETE /comments/{commentID}/reactions", authWithUserRL(http.HandlerFunc(deps.Comments.RemoveReaction)))
	}
	if deps.Reservations != nil {
		mux.Handle("POST /items/{itemID}/reservations", authWithUserRL(http.HandlerFunc(deps.Reservations.Create)))
		mux.Handle("GET /items/{itemID}/reservations", authWithUserRL(http.HandlerFunc(deps.Reservations.ListByItem)))
		mux.Handle("GET /items/{itemID}/availability", authWithUserRL(http.HandlerFunc(deps.Reservations.Availability)))
		mux.Handle("GET /organizations/{orgID}/reservations", authWithUserRL(http.HandlerFunc(deps.Reservations.ListByOrganization)))
		mux.Handle("POST /reservations/{reservationID}/fulfill", authWithUserRL(http.HandlerFunc(deps.Reservations.Fulfill)))
		mux.Handle("POST /reservations/{reservationID}/cancel", authWithUserRL(http.HandlerFunc(deps.Reservations.Cancel)))
	}
	if deps.WebSocket != nil {
		mux.Handle("GET /ws", authWithUserRL(http.HandlerFunc(deps.WebSocket.ServeWS)))
	}

	authLimiter := ratelimit.NewPerIPLimiter(2*time.Second, 12, 4096)
	var withRL http.Handler = mux
	if !deps.SkipAuthRateLimit {
		withRL = authRateLimitMiddleware(authLimiter, deps.ClientIP)(mux)
	}

	handler := withRL
	if len(deps.CORSAllowedOrigins) > 0 {
		handler = corsMiddleware(deps.CORSAllowedOrigins)(handler)
	}
	return securityHeadersMiddleware(recoverMiddleware(loggingMiddleware(handler)))
}
