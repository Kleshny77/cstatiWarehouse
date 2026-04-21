package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type AuthHandler struct {
	auth *usecase.AuthUseCase
}

func NewAuthHandler(auth *usecase.AuthUseCase) *AuthHandler {
	return &AuthHandler{auth: auth}
}

type userDTO struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	LastName  string  `json:"last_name"`
	Email     string  `json:"email"`
	AvatarURL *string `json:"avatar_url,omitempty"`
}

func userToDTO(u *domain.User) userDTO {
	return userDTO{
		ID:        u.ID.String(),
		Name:      u.Name,
		LastName:  u.LastName,
		Email:     u.Email,
		AvatarURL: u.AvatarURL,
	}
}

type authResponse struct {
	AccessToken      string    `json:"access_token"`
	AccessExpiresAt  time.Time `json:"access_expires_at"`
	RefreshToken     string    `json:"refresh_token"`
	RefreshExpiresAt time.Time `json:"refresh_expires_at"`
	User             userDTO   `json:"user"`
}

func buildAuthResponse(user *domain.User, tokens domain.AuthTokens) authResponse {
	return authResponse{
		AccessToken:      tokens.AccessToken,
		AccessExpiresAt:  tokens.AccessExpiresAt,
		RefreshToken:     tokens.RefreshToken,
		RefreshExpiresAt: tokens.RefreshExpiresAt,
		User:             userToDTO(user),
	}
}

type registerRequest struct {
	Name      string  `json:"name"`
	LastName  string  `json:"last_name"`
	Email     string  `json:"email"`
	Password  string  `json:"password"`
	AvatarURL *string `json:"avatar_url,omitempty"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	user, tokens, err := h.auth.Register(r.Context(), usecase.RegisterInput{
		Name: req.Name, LastName: req.LastName, Email: req.Email, Password: req.Password,
		AvatarURL: req.AvatarURL,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, buildAuthResponse(user, tokens))
}

type updateProfileRequest struct {
	Name      *string `json:"name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
	AvatarURL *string `json:"avatar_url,omitempty"`
}

// UpdateProfile — PATCH /auth/me. Любое подмножество полей.
func (h *AuthHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req updateProfileRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	user, err := h.auth.UpdateProfile(r.Context(), userID, usecase.UpdateProfileInput{
		Name: req.Name, LastName: req.LastName, AvatarURL: req.AvatarURL,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, userToDTO(user))
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	user, tokens, err := h.auth.Login(r.Context(), usecase.LoginInput{
		Email: req.Email, Password: req.Password,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, buildAuthResponse(user, tokens))
}

type telegramRequest struct {
	IDToken string `json:"id_token"`
}

func (h *AuthHandler) Telegram(w http.ResponseWriter, r *http.Request) {
	var req telegramRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	user, tokens, err := h.auth.LoginWithTelegram(r.Context(), req.IDToken)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, buildAuthResponse(user, tokens))
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	user, tokens, err := h.auth.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, buildAuthResponse(user, tokens))
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	if err := h.auth.Logout(r.Context(), req.RefreshToken); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	user, err := h.auth.CurrentUser(r.Context(), userID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, userToDTO(user))
}

func decodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		if errors.Is(err, io.EOF) {
			return domain.NewValidationError("request body is required")
		}
		return domain.NewValidationError("invalid JSON body: " + err.Error())
	}
	return nil
}
