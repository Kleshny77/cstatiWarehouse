package httpapi

import (
	"net/http"
	"strings"
)

// corsMiddleware добавляет CORS заголовки для поддержки веб-клиентов и разработки.
// Для production рекомендуется ограничить allowedOrigins конкретными доменами.
func corsMiddleware(allowedOrigins []string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")

			// Проверяем, разрешён ли origin
			if origin != "" && isOriginAllowed(origin, allowedOrigins) {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
			}

			// Разрешённые методы
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")

			// Разрешённые заголовки (включая Authorization для JWT)
			w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-CSRF-Token, X-Request-ID")

			// Заголовки, которые клиент может читать
			w.Header().Set("Access-Control-Expose-Headers", "Link, X-Total-Count, X-Page, X-Per-Page, Retry-After")

			// Время кеширования preflight запроса (24 часа)
			w.Header().Set("Access-Control-Max-Age", "86400")

			// Обработка preflight запроса
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// isOriginAllowed проверяет, разрешён ли origin.
// Поддерживает:
// - Точное совпадение: "https://example.com"
// - Wildcard: "*" (разрешает все origins)
// - Localhost для разработки: "http://localhost:*"
func isOriginAllowed(origin string, allowedOrigins []string) bool {
	if len(allowedOrigins) == 0 {
		return false
	}

	for _, allowed := range allowedOrigins {
		allowed = strings.TrimSpace(allowed)

		// Wildcard - разрешаем всё (только для dev!)
		if allowed == "*" {
			return true
		}

		// Точное совпадение
		if allowed == origin {
			return true
		}

		// Localhost с любым портом для разработки
		if allowed == "http://localhost:*" && isLocalhostOrigin(origin) {
			return true
		}

		// HTTPS localhost с любым портом
		if allowed == "https://localhost:*" && isLocalhostOriginHTTPS(origin) {
			return true
		}
	}

	return false
}

// isLocalhostOrigin проверяет, является ли origin localhost с HTTP
func isLocalhostOrigin(origin string) bool {
	return strings.HasPrefix(origin, "http://localhost:") ||
		strings.HasPrefix(origin, "http://127.0.0.1:")
}

// isLocalhostOriginHTTPS проверяет, является ли origin localhost с HTTPS
func isLocalhostOriginHTTPS(origin string) bool {
	return strings.HasPrefix(origin, "https://localhost:") ||
		strings.HasPrefix(origin, "https://127.0.0.1:")
}
