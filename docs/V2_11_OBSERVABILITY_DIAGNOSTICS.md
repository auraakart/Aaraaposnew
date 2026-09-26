# V2.11 — Observability & Diagnostics Foundation

## Purpose

V2.11 makes technical failures easier to diagnose without introducing an external logging platform or exposing customer/business content in logs.

The milestone covers two surfaces:
- server request correlation and structured/redacted logs
- local POS diagnostics for Owner/Manager

## Server request correlation

Every request receives an `x-request-id`.

A caller-supplied request ID is accepted only when it:
- is 1–128 characters
- contains only letters, digits, dot, underscore, colon or hyphen

Malformed values, including CR/LF log-injection attempts, are replaced with a generated UUID.

The same request ID is returned in the response.

## Query-safe request paths

Structured request logs use only the parsed URL path.

Query parameters are never written into the request path log field.

Example:

`/orders?token=secret&customer=123`

is logged as:

`/orders`

## Structured log contract

Server logs are JSON-line records with controlled fields such as:
- timestamp
- level
- event
- request ID
- method
- path
- status code
- duration
- sanitized details

Event names use a constrained machine-readable format.

## Redaction

Structured log detail redaction covers common sensitive keys including:
- password
- secret
- token
- authorization
- cookie
- CVV/card/PAN identifiers
- phone/mobile
- email
- address
- receipt
- note
- payload/body

Matching values are replaced with `[REDACTED]`.

The safest rule remains: do not put personal or financial content into diagnostic metadata in the first place.

## Health and readiness

`GET /health` and `GET /ready` report:
- service name
- request ID
- process uptime
- scope = `process`

The scope is deliberate.

AaraaPOS does **not** claim database/provider readiness because the repository does not yet contain a deployed production database connection, payment provider or messaging provider.

Future infrastructure can extend readiness checks without changing the request-correlation/logging contract.

## POS local diagnostics

More → Diagnostics is restricted locally to Owner/Manager.

The screen exposes only technical state:
- SQLite quick-check result
- foreign-key enforcement status
- local SQLite schema version
- active product count
- finalized sale count
- audit-event count
- open-shift count
- sync Pending/Sending/Conflict/Rejected counts
- total unresolved sync count
- age of the oldest unresolved sync record

It does **not** display:
- customer names
- phone/email/address
- receipts
- notes
- sale amounts
- payment credentials
- product transaction detail

## Attention rules

The local diagnostics screen flags attention when:
- SQLite quick-check is not OK
- foreign-key enforcement is disabled
- sync conflicts exist
- rejected sync records exist

Pending offline work alone is not treated as a failure because offline operation is expected.

## Testing

Backend tests cover:
- safe request-ID acceptance
- malformed request-ID replacement
- query stripping
- nested log redaction
- structured request records
- process-scoped health output

Flutter/database tests cover:
- diagnostics attention rules
- unresolved-age calculation
- SQLite integrity status
- foreign-key status
- schema version
- sync counts
- safe technical counts
- Owner/Manager read access
- Cashier denial

## External boundary

Not claimed:
- centralized log aggregation
- SIEM integration
- production APM/tracing backend
- OpenTelemetry exporter
- production alert paging
- deployed database/provider readiness
- remote device telemetry
- customer-data debugging exports

Those require production infrastructure and operational policy.
