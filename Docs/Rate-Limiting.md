# Rate Limiting

## Overview

The cstatiWarehouse backend implements two-tier rate limiting to protect against abuse and ensure fair resource allocation:

1. **IP-based rate limiting** for authentication endpoints
2. **User-based rate limiting** for authenticated endpoints

## IP-Based Rate Limiting (Auth Endpoints)

### Configuration
- **Endpoints**: `POST /auth/*` (register, login, telegram, google, refresh, logout)
- **Rate**: 1 request per 2 seconds per IP
- **Burst**: 12 requests
- **Capacity**: 4096 unique IPs tracked

### Implementation
- Located in: [`backend/internal/infra/ratelimit/limiter.go`](../backend/internal/infra/ratelimit/limiter.go)
- Middleware: [`backend/internal/adapter/httpapi/middleware.go`](../backend/internal/adapter/httpapi/middleware.go) - `authRateLimitMiddleware`
- Uses token bucket algorithm via `golang.org/x/time/rate`
- Supports trusted proxy headers (X-Forwarded-For, X-Real-IP) when `TRUSTED_PROXY_CIDRS` is configured

### Behavior
- Returns `429 Too Many Requests` with error code `rate_limited` when limit exceeded
- Automatically evicts oldest IP when capacity (4096) is reached
- Can be disabled for testing via `RouterDeps.SkipAuthRateLimit = true`

## User-Based Rate Limiting (Authenticated Endpoints)

### Configuration
- **Endpoints**: All authenticated routes (items, organizations, events, categories, activity, uploads, notifications, WebSocket)
- **Rate**: 50 requests per second per user
- **Burst**: 100 requests
- **TTL**: 5 minutes (inactive limiters are cleaned up)

### Implementation
- Located in: [`backend/internal/infra/ratelimit/user_limiter.go`](../backend/internal/infra/ratelimit/user_limiter.go)
- Middleware: [`backend/internal/adapter/httpapi/middleware_user_ratelimit.go`](../backend/internal/adapter/httpapi/middleware_user_ratelimit.go)
- Factory: `httpapi.NewUserRateLimiter(rate, burst, ttl)`
- Initialization: [`backend/cmd/server/main.go`](../backend/cmd/server/main.go)

### Features
- **Per-user tracking**: Each authenticated user has their own rate limiter
- **Automatic cleanup**: Inactive limiters are removed after 5 minutes to prevent memory leaks
- **Thread-safe**: Uses `sync.RWMutex` for concurrent access
- **Graceful degradation**: Unauthenticated requests skip user rate limiting (fall back to IP-based)

### Behavior
- Returns `429 Too Many Requests` with error code `rate_limited` when limit exceeded
- User ID extracted from JWT token in request context
- Background goroutine cleans up inactive limiters every 1 minute

## Error Response

When rate limit is exceeded, the API returns:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "too many requests"
  }
}
```

**HTTP Status**: `429 Too Many Requests`

## Architecture

### Middleware Chain

```
Request
  ↓
securityHeadersMiddleware
  ↓
recoverMiddleware
  ↓
loggingMiddleware
  ↓
authRateLimitMiddleware (IP-based, only for /auth/*)
  ↓
authMiddleware (JWT validation)
  ↓
userRateLimitMiddleware (user-based, for authenticated routes)
  ↓
Handler
```

### Token Bucket Algorithm

Both rate limiters use the token bucket algorithm:
- **Tokens** are added to the bucket at a constant rate
- **Burst** defines the maximum bucket capacity
- Each request consumes one token
- If no tokens available, request is rejected with 429

### Memory Management

**IP-based limiter**:
- Fixed capacity of 4096 IPs
- LRU eviction when capacity reached
- No automatic cleanup (bounded by capacity)

**User-based limiter**:
- Unbounded number of users
- TTL-based cleanup (5 minutes of inactivity)
- Background cleanup goroutine runs every 1 minute
- Prevents memory leaks from inactive users

## Configuration

### Environment Variables

```bash
# Trusted proxy CIDRs for X-Forwarded-For support
TRUSTED_PROXY_CIDRS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

### Code Configuration

In [`backend/cmd/server/main.go`](../backend/cmd/server/main.go):

```go
// User rate limiter: 50 req/sec per user, burst 100, 5min TTL
userLimiter := httpapi.NewUserRateLimiter(50, 100, 5*time.Minute)
```

Adjust parameters based on your needs:
- **rate**: requests per second (10-100 recommended)
- **burst**: maximum burst size (20-200 recommended)
- **ttl**: cleanup interval (1-10 minutes recommended)

## Testing

### Disable IP-based rate limiting

For integration tests running on localhost:

```go
router := httpapi.NewRouter(httpapi.RouterDeps{
    // ... other deps
    SkipAuthRateLimit: true,
})
```

### Test rate limiting behavior

```bash
# Test IP-based limiting (auth endpoints)
for i in {1..15}; do
  curl -X POST http://localhost:8080/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"wrong"}'
  echo ""
done

# Test user-based limiting (authenticated endpoints)
TOKEN="your-jwt-token"
for i in {1..120}; do
  curl -X GET http://localhost:8080/items \
    -H "Authorization: Bearer $TOKEN"
  echo ""
done
```

## Monitoring

### Metrics to Track

1. **Rate limit hits**: Count of 429 responses
2. **Active limiters**: Number of tracked IPs/users
3. **Memory usage**: Size of limiter maps
4. **Cleanup efficiency**: Limiters removed per cleanup cycle

### Logging

Rate limit violations are logged via the logging middleware:

```
INFO rate limit exceeded ip=192.168.1.100 path=/auth/login
```

## Security Considerations

1. **DDoS Protection**: IP-based limiting protects auth endpoints from brute force
2. **Fair Usage**: User-based limiting prevents individual users from monopolizing resources
3. **Proxy Support**: Correctly handles X-Forwarded-For when behind reverse proxy
4. **Memory Safety**: TTL-based cleanup prevents memory exhaustion
5. **Graceful Degradation**: System remains functional even under rate limiting

## Future Improvements

1. **Redis-based limiting**: For distributed deployments
2. **Dynamic rate adjustment**: Based on server load
3. **Per-endpoint limits**: Different limits for different operations
4. **Rate limit headers**: Return `X-RateLimit-*` headers
5. **Metrics export**: Prometheus metrics for monitoring
6. **Configurable limits**: Via environment variables or config file
