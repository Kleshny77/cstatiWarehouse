package domain

import "errors"

var (
	ErrNotFound                = errors.New("not found")
	ErrEmailAlreadyUsed        = errors.New("email already used")
	ErrInvalidCreds            = errors.New("invalid credentials")
	ErrValidation              = errors.New("validation error")
	ErrUnauthorized            = errors.New("unauthorized")
	ErrForbidden               = errors.New("forbidden")
	ErrTelegramDisabled = errors.New("telegram login not configured")
	ErrGoogleDisabled   = errors.New("google login not configured")
	ErrAlreadyMember           = errors.New("user is already a member")
	ErrOwnerCannotLeave        = errors.New("owner cannot leave the organization")
	ErrCannotDeletePersonalOrg = errors.New("cannot delete personal organization")
	ErrInviteNotUsable         = errors.New("invite is not usable")
	ErrInviteWrongOrg          = errors.New("invite does not belong to organization")
	ErrCannotTargetOwner       = errors.New("cannot modify organization owner")
	ErrCannotTargetSelf        = errors.New("cannot perform this action on self")
	ErrConflict                = errors.New("conflict")
)

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
