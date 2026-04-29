package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	HTTPAddr            string
	HTTPReadTimeout     time.Duration
	HTTPWriteTimeout    time.Duration
	HTTPShutdownTimeout time.Duration

	DatabaseURL string
	// DatabaseRequireTLS — если true, DATABASE_URL не должен использовать sslmode=disable (прод).
	DatabaseRequireTLS bool

	JWTSecret     string
	JWTAccessTTL  time.Duration
	JWTRefreshTTL time.Duration

	TelegramClientID string
	TelegramIssuer   string
	TelegramJWKSURL  string

	GoogleClientID string

	UploadsDir           string
	PublicBaseURL        string
	MaxUploadBytes       int64
	UploadSigningSecret  string
	UploadURLTTL         time.Duration
	TrustedProxyCIDRsRaw string

	// CORSAllowedOrigins — список разрешённых origins для CORS (через запятую).
	// Примеры: "*" (все, только dev), "https://example.com", "http://localhost:*"
	CORSAllowedOrigins string
}

func (c Config) TelegramConfigured() bool {
	return strings.TrimSpace(c.TelegramClientID) != "" && strings.TrimSpace(c.TelegramJWKSURL) != ""
}

func (c Config) GoogleConfigured() bool {
	return strings.TrimSpace(c.GoogleClientID) != ""
}

// BindLANWarnings — проблемы привязки HTTP, из‑за которых телефон по Wi‑Fi не достучится до Mac (Safari / приложение).
func (c Config) BindLANWarnings() []string {
	if isLoopbackOnlyHTTPAddr(c.HTTPAddr) {
		return []string{
			"HTTP_ADDR слушает только loopback: устройства в LAN (iPhone) не подключатся. В backend/.env задайте HTTP_ADDR=:8080 и перезапустите сервер.",
		}
	}
	return nil
}

func isLoopbackOnlyHTTPAddr(addr string) bool {
	s := strings.TrimSpace(addr)
	if s == "" {
		return false
	}
	lower := strings.ToLower(s)
	// ":8080" — все интерфейсы (IPv4/IPv6).
	if strings.HasPrefix(lower, ":") && !strings.HasPrefix(lower, "::") {
		return false
	}
	if strings.HasPrefix(lower, "0.0.0.0:") {
		return false
	}
	if strings.HasPrefix(lower, "[::]:") {
		return false
	}
	if strings.HasPrefix(lower, "127.") {
		return true
	}
	if strings.HasPrefix(lower, "[::1]") {
		return true
	}
	if strings.HasPrefix(lower, "localhost:") {
		return true
	}
	return false
}

func Load() (Config, error) {
	cfg := Config{
		HTTPAddr:            getenv("HTTP_ADDR", ":8080"),
		HTTPReadTimeout:     getDuration("HTTP_READ_TIMEOUT", 10*time.Second),
		HTTPWriteTimeout:    getDuration("HTTP_WRITE_TIMEOUT", 10*time.Second),
		HTTPShutdownTimeout: getDuration("HTTP_SHUTDOWN_TIMEOUT", 15*time.Second),

		DatabaseURL:        os.Getenv("DATABASE_URL"),
		DatabaseRequireTLS: getenvBool("DATABASE_REQUIRE_TLS", false),

		JWTSecret:     os.Getenv("JWT_SECRET"),
		JWTAccessTTL:  getDuration("JWT_ACCESS_TTL", 15*time.Minute),
		JWTRefreshTTL: getDuration("JWT_REFRESH_TTL", 720*time.Hour),

		TelegramClientID: os.Getenv("TELEGRAM_CLIENT_ID"),
		TelegramIssuer:   getenv("TELEGRAM_ISSUER", "https://oauth.telegram.org"),
		TelegramJWKSURL:  getenv("TELEGRAM_JWKS_URL", "https://oauth.telegram.org/.well-known/jwks.json"),

		GoogleClientID: os.Getenv("GOOGLE_CLIENT_ID"),

		UploadsDir:           getenv("UPLOADS_DIR", "./uploads"),
		PublicBaseURL:        getenv("PUBLIC_BASE_URL", ""),
		MaxUploadBytes:       getInt64("MAX_UPLOAD_BYTES", 10<<20),
		UploadSigningSecret:  os.Getenv("UPLOAD_SIGNING_SECRET"),
		UploadURLTTL:         getDuration("UPLOAD_URL_TTL", 168*time.Hour),
		TrustedProxyCIDRsRaw: os.Getenv("TRUSTED_PROXY_CIDRS"),
		CORSAllowedOrigins:   getenv("CORS_ALLOWED_ORIGINS", "http://localhost:*"),
	}

	if err := cfg.validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) validate() error {
	if c.DatabaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}
	if c.DatabaseRequireTLS && strings.Contains(strings.ToLower(c.DatabaseURL), "sslmode=disable") {
		return errors.New("DATABASE_REQUIRE_TLS is true but DATABASE_URL uses sslmode=disable")
	}
	if len(c.JWTSecret) < 32 {
		return errors.New("JWT_SECRET must be at least 32 characters long")
	}
	if c.JWTAccessTTL <= 0 {
		return errors.New("JWT_ACCESS_TTL must be positive")
	}
	if c.JWTRefreshTTL <= c.JWTAccessTTL {
		return errors.New("JWT_REFRESH_TTL must be greater than JWT_ACCESS_TTL")
	}
	uploadSecret := strings.TrimSpace(c.UploadSigningSecret)
	if uploadSecret == "" {
		uploadSecret = c.JWTSecret
	}
	if len(uploadSecret) < 32 {
		return errors.New("UPLOAD_SIGNING_SECRET (or JWT_SECRET if unset) must be at least 32 characters")
	}
	if c.UploadURLTTL <= 0 {
		return errors.New("UPLOAD_URL_TTL must be positive")
	}
	return nil
}

// EffectiveUploadSigningSecret — UPLOAD_SIGNING_SECRET или JWT_SECRET.
func (c Config) EffectiveUploadSigningSecret() string {
	if strings.TrimSpace(c.UploadSigningSecret) != "" {
		return strings.TrimSpace(c.UploadSigningSecret)
	}
	return c.JWTSecret
}

// ParsedCORSAllowedOrigins возвращает список разрешённых origins для CORS.
func (c Config) ParsedCORSAllowedOrigins() []string {
	raw := strings.TrimSpace(c.CORSAllowedOrigins)
	if raw == "" {
		return nil
	}

	parts := strings.Split(raw, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		trimmed := strings.TrimSpace(p)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func getenvBool(key string, fallback bool) bool {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	switch strings.ToLower(raw) {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getInt64(key string, fallback int64) int64 {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		panic(fmt.Errorf("invalid int64 for %s: %w", key, err))
	}
	return v
}

func getDuration(key string, fallback time.Duration) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	d, err := time.ParseDuration(raw)
	if err != nil {
		panic(fmt.Errorf("invalid duration for %s: %w", key, err))
	}
	return d
}
