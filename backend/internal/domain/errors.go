package domain

import "errors"

// Sentinel-ошибки домена. Адаптеры мапят их в HTTP-коды в одном месте.
var (
	ErrNotFound           = errors.New("not found")
	ErrEmailAlreadyUsed   = errors.New("email already used")
	ErrInvalidCreds       = errors.New("invalid credentials")
	ErrValidation         = errors.New("validation error")
	ErrUnauthorized       = errors.New("unauthorized")
	ErrForbidden          = errors.New("forbidden")
	ErrTelegramDisabled   = errors.New("telegram login not configured")
	ErrAlreadyMember      = errors.New("user is already a member")
	ErrOwnerCannotLeave   = errors.New("owner cannot leave the organization")
	ErrCannotDeletePersonalOrg = errors.New("cannot delete personal organization")
)

// ValidationError оборачивает человекочитаемое сообщение,
// но остаётся совместим с errors.Is(err, ErrValidation).
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}

func (e *ValidationError) Is(target error) bool {
	return target == ErrValidation
}

func NewValidationError(msg string) error {
	return &ValidationError{Message: msg}
}
