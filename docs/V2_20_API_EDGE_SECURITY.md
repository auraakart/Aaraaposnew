# V2.20 — API Edge Security Foundation

## Purpose

V2.20 hardens the HTTP edge introduced in V2.19 before adding persistent business mutation endpoints.

The controls are repository-local and low-cost. They are not a replacement for a production API gateway or WAF.

## Security headers

All HTTP responses now receive:

- Cache-Control: no-store
- Content-Security-Policy with default-src 'none'
- frame-ancestors 'none'
- base-uri 'none'
- form-action 'none'
- Cross-Origin-Resource-Policy: same-site
- Referrer-Policy: no-referrer
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY

The existing request ID and JSON content type remain present where appropriate.

## CORS

Browser access is deny-by-default.

Allowed origins are configured only through:

`CORS_ALLOWED_ORIGINS`

The value is a comma-separated exact-origin allowlist.

Rules:

- HTTPS is required for non-local origins.
- HTTP is allowed only for localhost/127.0.0.1 development.
- origins containing credentials, paths, query strings or fragments are rejected.
- an unconfigured allowlist means browser cross-origin requests are denied.
- requests without an Origin header, such as native mobile/server traffic, continue normally.
- no wildcard origin is used.
- credentials are not enabled implicitly.

Valid preflight responses expose only:

- GET
- POST
- OPTIONS
- Authorization
- Content-Type
- X-Request-ID

Preflight cache lifetime is 600 seconds.

## Content type

Known protected write routes require:

`Content-Type: application/json`

Parameters such as `charset=utf-8` are accepted.

Incorrect or missing content type returns:

- HTTP 415
- `UNSUPPORTED_MEDIA_TYPE`

Known resources with the wrong HTTP method return:

- HTTP 405
- `METHOD_NOT_ALLOWED`
- `Allow` header

The method contract is evaluated before reading the request body.

## Rate limiting

Versioned `/v1/*` routes use a bounded in-process fixed-window guard:

- 120 requests
- per 60 seconds
- per remote socket address + route
- at most 10,000 tracked keys

Responses include:

- RateLimit-Limit
- RateLimit-Remaining
- RateLimit-Reset

Rejected requests return:

- HTTP 429
- `RATE_LIMITED`
- `Retry-After`

The limiter deliberately uses the actual socket address.

AaraaPOS does **not** trust `X-Forwarded-For` until a trusted reverse-proxy topology is explicitly configured.

This limiter is defense-in-depth for one process. A distributed production deployment still requires gateway/shared rate limiting.

## Server limits

The Node server now applies:

- request timeout: 15 seconds
- header timeout: 10 seconds
- keep-alive timeout: 5 seconds
- maximum header count: 100
- request body maximum: 256 KiB

Health/readiness remains outside the versioned API rate limiter.

## Request order

For `/v1/*` requests the server applies:

1. request correlation and security headers
2. CORS policy
3. rate limit
4. preflight/method/media-type contract
5. body-size control
6. authentication
7. validation
8. authorization
9. domain execution

This keeps protected business work behind the cheaper edge checks.

## Tests

Tests cover:

- exact CORS origin parsing
- HTTPS-first origin configuration
- localhost development exception
- deny-by-default browser origins
- malformed Origin rejection
- controlled preflight methods/headers
- security/no-cache response headers
- JSON media type parsing
- rate-limit exhaustion/reset
- bounded limiter key behavior
- rate-limit response headers
- known-route 405/Allow behavior

## External boundary

Not claimed in V2.20:

- production API gateway
- WAF/bot mitigation
- distributed/shared rate limiter
- DDoS protection
- trusted reverse-proxy/X-Forwarded-For configuration
- TLS termination configuration
- mTLS
- production CORS allowlist values
- public internet deployment
- external penetration testing
