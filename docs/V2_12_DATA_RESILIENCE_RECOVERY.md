# V2.12 — Data Resilience & Recovery Foundation

## Purpose

V2.12 introduces recovery-safety contracts without pretending that production backup storage or destructive restore has been implemented.

The milestone establishes:
- encrypted checkpoint metadata
- SHA-256 content verification
- tenant/store scope validation
- schema compatibility assessment
- recovery-point age warnings
- unresolved-local-write blocking
- dry-run rehearsal evidence
- a non-destructive local recovery-readiness screen

## Recovery checkpoint contract

A recovery checkpoint carries:
- checkpoint ID
- organization/business scope
- optional store scope
- schema version
- creation time
- SHA-256 content hash
- encrypted=true requirement
- storage reference
- status
- record-count summary

Checkpoint payload bytes can be verified against the recorded SHA-256 digest before any recovery assessment.

## Scope isolation

A checkpoint cannot be assessed for a different:
- organization
- business
- store, when store-scoped

Cross-tenant/store mismatches are hard blockers.

Business-scoped checkpoints cannot declare a store ID.

## Restore-safety assessment

A checkpoint dry-run is blocked when:
- tenant/business/store scope does not match
- checkpoint status is invalid/expired
- checkpoint schema is newer than the runtime
- unresolved local writes exist

Warnings are emitted when:
- checkpoint schema is older and requires migration
- checkpoint is older than the target recovery-point objective
- checkpoint timestamp is in the future
- checkpoint hash has not yet been verified

V2.12 does not execute a restore.

## Server persistence

Migration `0018_recovery_checkpoints.sql` adds:

### recovery_checkpoint
Tenant/business/store-scoped metadata for encrypted checkpoint evidence.

### recovery_rehearsal
Dry-run-only recovery rehearsal evidence containing:
- checkpoint
- actor
- result
- blockers
- warnings
- request ID
- timestamp

Both tables use tenant row-level security.

## POS recovery readiness

More → Recovery Readiness is Owner/Manager-only through the same local authorization boundary used by Diagnostics/Audit.

It evaluates:
- SQLite integrity
- foreign-key enforcement
- local schema version
- unresolved sync writes
- whether an encrypted backup provider is configured

The current repository has no backup provider configured, so the UI explicitly reports that external backup creation is unavailable.

Unresolved local writes block restore assessment because replacing local data could otherwise discard unsynchronized financial/audit evidence.

## Integrity principles

V2.12 deliberately does not:
- overwrite local SQLite
- delete current records
- create a restore button
- upload raw backups
- store backup credentials
- claim cloud backup encryption
- claim recovery-point or recovery-time SLA compliance

Recovery remains evidence-first and non-destructive until production storage, key management and restore orchestration are selected.

## Testing

Backend tests cover:
- exact-byte SHA-256 verification
- tenant/store mismatch blocking
- unresolved-write blocking
- schema/RPO warnings
- encryption requirement

Flutter tests cover:
- local restore-assessment readiness
- unresolved-write blocking
- database-integrity blocking
- explicit provider-not-configured state

## External boundary

Requires future production integration:
- encrypted object storage/provider
- key management
- scheduled backup creation
- retention policy
- immutable/off-site copies
- full restore orchestration
- recovery drill against production-like infrastructure
- measured RPO/RTO
- production credential and access controls
