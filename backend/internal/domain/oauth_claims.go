package domain

// GoogleIDClaims — проверенные поля из Google id_token.
type GoogleIDClaims struct {
	Sub        string
	Email      string
	GivenName  string
	FamilyName string
	FullName   string
	PictureURL *string
}
