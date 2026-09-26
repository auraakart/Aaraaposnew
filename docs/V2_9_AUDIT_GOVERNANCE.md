# V2.9 — Audit & Governance Foundation

## Purpose

V2.9 closes the repository gap between the baseline permission model and the actual POS client: Owner/Manager now have a consolidated, append-oriented history for critical committed actions.

Audit evidence does not replace financial or inventory ledgers.

The authoritative business record remains:
- Sale / Sale Return
- Payment / Refund
- Stock Movement
- Expense
- Shift / Cash Movement
- Supplier Ledger
- Employee record

Audit events point back to those source entities.

## Local audit events

SQLite schema version 12 adds `local_audit_event` with:
- event ID
- actor user ID
- action
- affected entity type
- affected entity ID
- occurrence timestamp
- outcome
- metadata JSON

Application code exposes no edit/delete path for audit events.

Critical successful actions recorded in this milestone include:
- sale finalized
- sale returned
- stock movement
- shift opened
- shift closed
- drawer cash movement
- expense recorded
- employee created
- supplier payment

Each audit insert occurs in the same SQLite transaction as the source operation wherever the source operation is transactional.

If the source transaction rolls back, its audit event rolls back with it.

## Synchronization

Each local audit event also creates an outbox envelope with:
- tenant/business/store/terminal scope
- actor
- action
- affected entity
- timestamp
- outcome
- safe metadata
- idempotency key

This makes audit synchronization replay-safe without turning audit into a second source of business truth.

## Access control

Local Audit History is readable only when the active local employee role is:
- Owner
- Manager

Cashier and Stock Worker are denied local audit-history access.

Server RBAC already treats `audit:read` the same way and regression tests lock that boundary.

UI hiding is not treated as the security boundary.

## Server audit contract

The server audit domain validates:
- required tenant/entity/actor/request identity
- parseable timestamp
- outcome
- metadata safety

Sensitive metadata keys such as password, secret, token, authorization, CVV and card/PAN identifiers are rejected.

Migration `0017_audit_governance.sql` extends server audit evidence with:
- terminal ID
- outcome

and adds a terminal/time index.

## Audit History UX

More → Audit History shows up to the latest 200 local audit events with:
- action label
- source entity/reference
- local timestamp
- actor identifier
- outcome

The view is intentionally read-only.

## Testing

Backend tests cover:
- valid audit event contract
- stable tenant-scoped audit dedupe key
- secret/card-sensitive metadata rejection
- invalid timestamps
- Owner/Manager-only audit permission

Flutter/database tests cover:
- source-linked sale audit
- source-linked return audit
- expense audit
- employee audit
- Owner read access
- Cashier denial
- bounded audit-history queries

## Boundaries

Not claimed in V2.9:
- production SIEM export
- remote immutable/WORM storage
- cryptographic hash-chain notarization
- audit of failed authentication attempts
- audit of server-side access events not yet received by the device
- regulatory certification

Those require production identity, infrastructure and operational integrations.
