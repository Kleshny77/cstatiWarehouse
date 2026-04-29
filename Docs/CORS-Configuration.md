# CORS Configuration

## Overview

The cstatiWarehouse backend implements CORS (Cross-Origin Resource Sharing) middleware to enable secure cross-origin requests from web browsers and development environments.

## What is CORS?

CORS is a security mechanism that allows a web application running at one origin to access resources from a different origin. Without CORS headers, browsers block cross-origin requests by default (Same-Origin Policy).

**Note**: Native iOS apps (using URLSession) do NOT require CORS headers, as they don't enforce Same-Origin Policy. CORS is only needed for:
- Web-based clients (React, Vue, Angular, etc.)
- Development tools (Postman, curl with browser-like behavior)
- WebView-based mobile apps

## Implementation

### Middleware

Located in: [`backend/internal/adapter/httpapi/middleware_cors.go`](../backend/internal/adapter/httpapi/middleware_cors.go)

**Key Features**:
- Origin validation against allowlist
- Preflight request handling (OPTIONS)
- Credentials support
- Configurable allowed origins

### CORS Headers

The middleware sets the following headers:

```http
Access-Control-Allow-Origin: <origin>
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Accept, Authorization, Content-Type, X-CSRF-Token, X-Request-ID
Access-Control-Expose-Headers: Link, X-Total-Count, X-Page, X-Per-Page, Retry-After
Access-Control-Max-Age: 86400
```

### Preflight Requests

The middleware automatically handles OPTIONS preflight requests:
- Returns `204 No Content`
- Includes all CORS headers
- Caches response for 24 hours (86400 seconds)

## Configuration

### Environment Variable

```bash
# Development (allow localhost with any port)
CORS_ALLOWED_ORIGINS="http://localhost:*"

# Production (specific domains)
CORS_ALLOWED_ORIGINS="https://app.example.com,https://admin.example.com"

# Development (allow all origins - NOT RECOMMENDED for production!)
CORS_ALLOWED_ORIGINS="*"

# Multiple origins (comma-separated)
CORS_ALLOWED_ORIGINS="https://example.com,http://localhost:*,https://staging.example.com"
```

### Default Value

If `CORS_ALLOWED_ORIGINS` is not set, the default is:
```
http://localhost:*
```

This allows development from any localhost port (e.g., `http://localhost:3000`, `http://localhost:5173`).

### Origin Patterns

The middleware supports several origin patterns:

1. **Exact match**:
   ```
   https://example.com
   ```
   Only allows requests from exactly `https://example.com`

2. **Wildcard** (⚠️ Use only in development):
   ```
   *
   ```
   Allows requests from ANY origin

3. **Localhost with any port**:
   ```
   http://localhost:*
   ```
   Allows `http://localhost:3000`, `http://localhost:8080`, etc.

4. **HTTPS localhost with any port**:
   ```
   https://localhost:*
   ```
   Allows `https://localhost:3000`, `https://localhost:8443`, etc.

## Security Considerations

### Production Best Practices

1. **Never use wildcard (`*`) in production**
   ```bash
   # ❌ BAD - allows any origin
   CORS_ALLOWED_ORIGINS="*"
   
   # ✅ GOOD - specific domains only
   CORS_ALLOWED_ORIGINS="https://app.example.com"
   ```

2. **Use HTTPS in production**
   ```bash
   # ❌ BAD - HTTP in production
   CORS_ALLOWED_ORIGINS="http://app.example.com"
   
   # ✅ GOOD - HTTPS only
   CORS_ALLOWED_ORIGINS="https://app.example.com"
   ```

3. **Limit to necessary origins**
   ```bash
   # Only include origins that actually need access
   CORS_ALLOWED_ORIGINS="https://app.example.com,https://admin.example.com"
   ```

### Development vs Production

**Development** (`backend/.env`):
```bash
CORS_ALLOWED_ORIGINS="http://localhost:*,https://localhost:*"
```

**Production** (environment variables):
```bash
CORS_ALLOWED_ORIGINS="https://app.example.com"
```

## Middleware Chain

CORS middleware is applied early in the chain to ensure preflight requests are handled before authentication:

```
Request
  ↓
corsMiddleware (if configured)
  ↓
securityHeadersMiddleware
  ↓
recoverMiddleware
  ↓
loggingMiddleware
  ↓
authRateLimitMiddleware
  ↓
authMiddleware
  ↓
userRateLimitMiddleware
  ↓
Handler
```

## Testing CORS

### Test Preflight Request

```bash
curl -X OPTIONS http://localhost:8080/items \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  -v
```

Expected response:
```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Accept, Authorization, Content-Type, X-CSRF-Token, X-Request-ID
Access-Control-Max-Age: 86400
```

### Test Actual Request

```bash
curl -X GET http://localhost:8080/items \
  -H "Origin: http://localhost:3000" \
  -H "Authorization: Bearer <token>" \
  -v
```

Expected response includes:
```http
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Credentials: true
```

### Test Blocked Origin

```bash
curl -X GET http://localhost:8080/items \
  -H "Origin: https://evil.com" \
  -H "Authorization: Bearer <token>" \
  -v
```

Expected: No `Access-Control-Allow-Origin` header (browser will block)

## Common Issues

### Issue: CORS error in browser console

```
Access to fetch at 'http://localhost:8080/items' from origin 'http://localhost:3000' 
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
```

**Solution**: Add your origin to `CORS_ALLOWED_ORIGINS`:
```bash
CORS_ALLOWED_ORIGINS="http://localhost:3000"
# or for any localhost port:
CORS_ALLOWED_ORIGINS="http://localhost:*"
```

### Issue: Preflight request fails with 401

**Problem**: Authentication middleware runs before CORS middleware

**Solution**: This is already handled correctly - CORS middleware runs before auth middleware in the chain.

### Issue: Credentials not working

```javascript
// Frontend code
fetch('http://localhost:8080/items', {
  credentials: 'include',  // Trying to send cookies
  headers: {
    'Authorization': 'Bearer token'
  }
})
```

**Solution**: The middleware already sets `Access-Control-Allow-Credentials: true`. Ensure your origin is in the allowlist (wildcard `*` doesn't work with credentials).

## iOS Native App

**Important**: iOS native apps using `URLSession` do NOT need CORS configuration. CORS is a browser security feature.

If you're building a web version of the app or using WebView, then CORS configuration is necessary.

## Disabling CORS

To disable CORS (not recommended):

```bash
# Don't set CORS_ALLOWED_ORIGINS, or set it to empty
CORS_ALLOWED_ORIGINS=""
```

The middleware will not be applied if `CORSAllowedOrigins` is empty.

## Code Reference

### Middleware Implementation

```go
// backend/internal/adapter/httpapi/middleware_cors.go
func corsMiddleware(allowedOrigins []string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            origin := r.Header.Get("Origin")
            
            if origin != "" && isOriginAllowed(origin, allowedOrigins) {
                w.Header().Set("Access-Control-Allow-Origin", origin)
                w.Header().Set("Access-Control-Allow-Credentials", "true")
            }

            // ... set other headers

            if r.Method == http.MethodOptions {
                w.WriteHeader(http.StatusNoContent)
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

### Router Integration

```go
// backend/internal/adapter/httpapi/router.go
handler := withRL
if len(deps.CORSAllowedOrigins) > 0 {
    handler = corsMiddleware(deps.CORSAllowedOrigins)(handler)
}
return securityHeadersMiddleware(recoverMiddleware(loggingMiddleware(handler)))
```

### Configuration

```go
// backend/internal/infra/config/config.go
type Config struct {
    // ...
    CORSAllowedOrigins string
}

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
```

## Resources

- [MDN: CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [W3C CORS Specification](https://www.w3.org/TR/cors/)
- [OWASP: CORS Security](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html#cross-origin-resource-sharing)
