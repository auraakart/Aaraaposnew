# V2.19 — Authenticated API Surface Foundation

## Purpose

V2.19 closes a structural backend gap: AaraaPOS already had tested domain modules, but the Node server exposed only health/readiness.

This milestone adds the first protected HTTP API surface while deliberately refusing to invent a production token verifier.

## Authentication boundary

Protected handlers depend on a `RequestAuthenticator` interface.

The production Node server currently uses `UnconfiguredRequestAuthenticator`.

Therefore protected `/v1/*` endpoints fail closed with:

- HTTP 503
- `AUTHENTICATION_UNAVAILABLE`

until a real OIDC/passwordless/service-token verifier is configured.

The server does not trust user/store/role headers as identity.

Local device PINs remain invalid remote credentials.

## Initial endpoints

### GET /v1/session

Returns the authenticated principal's:

- user ID
- organization ID
- allowed business IDs
- allowed store IDs
- role
- request ID

It never returns credentials or token material.

### POST /v1/sales/quote

Runs the existing deterministic sale-pricing domain through HTTP.

Request scope contains:

- organizationId
- businessId
- storeId
- taxMode
- sale lines

Before pricing, the handler requires:

1. authenticated principal
2. organization/business/store scope match
3. `sale:create` permission

A valid Stock Worker is therefore denied even for a matching tenant/store because that role lacks `sale:create`.

A Cashier is denied when requesting another store outside their authenticated scope.

The endpoint is non-persistent; it quotes deterministic totals and does not finalize a sale.

## Validation and limits

The HTTP adapter enforces a maximum request body of 256 KiB.

The API layer validates:

- JSON object body
- required IDs
- tax mode
- non-empty line list
- maximum 500 lines
- integer paise/milli-unit values
- tax basis points
- price mode
- optional discount metadata

Validation errors return HTTP 400 with stable code `INVALID_REQUEST`.

## Error contract

Protected API responses use request-correlated envelopes:

- 400 INVALID_REQUEST
- 401 UNAUTHENTICATED
- 403 FORBIDDEN
- 404 NOT_FOUND
- 413 PAYLOAD_TOO_LARGE
- 503 AUTHENTICATION_UNAVAILABLE
- 500 INTERNAL_ERROR

The existing `x-request-id` correlation remains present.

## Security model

V2.19 establishes the order:

1. authenticate
2. validate request
3. authorize role + tenant/store scope
4. execute domain logic

For the sale quote route, authentication occurs before request parsing so an unauthenticated caller cannot use protected business logic as an anonymous calculation endpoint.

RLS remains database defense-in-depth for persistent routes added later.

## Tests

Tests cover:

- authenticated session response
- valid Cashier quote
- deterministic tax totals
- cross-store denial
- Stock Worker role denial
- invalid JSON
- invalid tax mode
- 401 authentication failure
- 503 unconfigured-production-auth behavior
- unknown route 404

## External boundary

Not claimed in V2.19:

- production OIDC/passwordless integration
- signed JWT verification
- API key issuance
- refresh-token/session revocation
- persistent sale creation endpoint
- database transaction orchestration over HTTP
- rate limiting / WAF
- public internet deployment
- API gateway
- production CORS policy
- external penetration testing

Those belong to later production/integration milestones.
