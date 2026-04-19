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

	JWTSecret     string
	JWTAccessTTL  time.Duration
	JWTRefreshTTL time.Duration

	TelegramClientID string
	TelegramIssuer   string
	TelegramJWKSURL  string

	UploadsDir       string
	PublicBaseURL    string
	MaxUploadBytes   int64
}

func (c Config) TelegramConfigured() bool {
	return strings.TrimSpace(c.TelegramClientID) != "" && strings.TrimSpace(c.TelegramJWKSURL) != ""
}

func Load() (Config, error) {
	cfg := Config{
		HTTPAddr:            getenv("HTTP_ADDR", ":8080"),
		HTTPReadTimeout:     getDuration("HTTP_READ_TIMEOUT", 10*time.Second),
		HTTPWriteTimeout:    getDuration("HTTP_WRITE_TIMEOUT", 10*time.Second),
		HTTPShutdownTimeout: getDuration("HTTP_SHUTDOWN_TIMEOUT", 15*time.Second),

		DatabaseURL: os.Getenv("DATABASE_URL"),

		JWTSecret:     os.Getenv("JWT_SECRET"),
		JWTAccessTTL:  getDuration("JWT_ACCESS_TTL", 15*time.Minute),
		JWTRefreshTTL: getDuration("JWT_REFRESH_TTL", 720*time.Hour),

		TelegramClientID: os.Getenv("TELEGRAM_CLIENT_ID"),
		TelegramIssuer:   getenv("TELEGRAM_ISSUER", "https://oauth.telegram.org"),
		TelegramJWKSURL:  getenv("TELEGRAM_JWKS_URL", "https://oauth.telegram.org/.well-known/jwks.json"),

		UploadsDir:    getenv("UPLOADS_DIR", "./uploads"),
		PublicBaseURL: getenv("PUBLIC_BASE_URL", ""),
		MaxUploadBytes: getInt64("MAX_UPLOAD_BYTES", 10<<20),
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
	if len(c.JWTSecret) < 32 {
		return errors.New("JWT_SECRET must be at least 32 characters long")
	}
	if c.JWTAccessTTL <= 0 {
		return errors.New("JWT_ACCESS_TTL must be positive")
	}
	if c.JWTRefreshTTL <= c.JWTAccessTTL {
		return errors.New("JWT_REFRESH_TTL must be greater than JWT_ACCESS_TTL")
	}
	return nil
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
