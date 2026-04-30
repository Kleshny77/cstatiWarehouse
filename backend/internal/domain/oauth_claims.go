package domain

type GoogleIDClaims struct {
	Sub        string
	Email      string
	GivenName  string
	FamilyName string
	FullName   string
	PictureURL *string
}
