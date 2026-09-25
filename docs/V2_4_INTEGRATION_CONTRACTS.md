# V2.4 — Integration Contracts

## Purpose

V2.4 makes AaraaPOS ready for real external providers and authenticated synchronization without claiming that any production provider is already connected.

The milestone deliberately keeps the modular-monolith / offline-first architecture. It does not add queues, Kafka, Redis or other infrastructure without a concrete need.

## Sync contract

Every sync envelope carries:
- outbox/event ID
- entity type
- entity ID
- organization, business, store and terminal scope
- idempotency key
- schema version
- creation time
- object payload

The server contract validates required scope and schema metadata before ingestion.

### State machine

Local outbox lifecycle:

Pending → Sending → Acknowledged

Sending may instead become:
- Conflict
- Rejected

Sending, Conflict and Rejected may explicitly retry to Pending.

Acknowledged items cannot be silently reopened.

The local queue retains:
- schema version
- attempt count
- last-attempt timestamp
- server conflict/rejection message

## Replay and idempotency

The server integration contract distinguishes:
- first submission → acknowledged
- exact replay of the same idempotency key/entity/payload hash → acknowledged as idempotent replay
- reuse of an idempotency key for different content → explicit conflict

PostgreSQL persists a tenant-scoped sync ingestion receipt with a unique organization/idempotency key pair.

Financial replay is never handled as last-write-wins.

## Conflict classes

The repository classifies syncable records into:
- append-only financial
- inventory movement
- master data
- configuration/security

Examples:

Append-only financial:
- sale
- return/refund
- payment
- customer credit
- loyalty ledger
- promotion redemption
- expense
- purchase/supplier financial evidence

Inventory:
- stock movement
- store transfer

Configuration/security:
- loyalty program
- promotion
- tax configuration
- employee role
- store access

Master data covers ordinary mutable records such as product/customer metadata.

The classification is a contract for future server resolution; V2.4 does not fabricate merge outcomes that require an authenticated server.

## Provider capability contract

A provider must declare:
- provider identity
- configured state
- supported capabilities

Supported capability vocabulary includes:
- payment charge
- payment refund
- payment query
- webhook
- message send
- tax submit
- accounting export

A capability is usable only when the provider is configured and explicitly declares it.

This prevents the UI/domain layer from inferring support merely because a provider name exists.

## Webhook security contract

Provider webhook processing requires:
- HMAC-SHA256 signature verification
- constant-time signature comparison
- minimum secret strength at the contract boundary
- freshness/timestamp validation
- unique provider event ID
- persistent payload hash
- explicit accepted/duplicate/rejected/processed state

Provider event IDs map to stable dedupe keys.

The repository stores no provider secrets in the event tables. Configuration references are identifiers to secret/config storage, not credentials themselves.

## Persistence

Migration `0013_integration_contracts.sql` adds:
- `sync_ingest_receipt`
- `integration_provider`
- `provider_webhook_event`

All carry tenant scope and RLS policies.

Local SQLite schema v9 extends `sync_outbox` with:
- schema version
- attempt count
- last-attempt timestamp

## User experience

More → Integrations & Sync exposes:
- Pending
- Sending
- Conflict
- Rejected counts
- unresolved queue items
- attempt count
- schema version
- provider boundary status
- explicit retry for Conflict/Rejected

Cash remains local and available.

UPI/Card remain unavailable until a real provider adapter and required capabilities are configured.

## External boundary

Not claimed in V2.4:
- production authentication/session issuance
- deployed sync API endpoints
- actual network transport from POS to server
- real UPI/card gateway
- real webhook endpoint registration
- production secrets
- messaging/tax/accounting provider credentials
- provider certification or compliance validation

These contracts make those integrations safer to implement later; they do not simulate successful external operations.
