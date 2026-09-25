# V1.2 — Inventory

## Scope

V1.2 makes stock a traceable, offline-capable workflow rather than a mutable quantity field.

Implemented:
- append-only stock movements
- opening / receive / sale / return / adjustment / damage / loss / transfer movement types
- movement-direction validation in both domain logic and PostgreSQL constraints
- reasons required for adjustment, damage and loss
- local SQLite stock movement ledger
- automatic stock reduction when an offline sale is finalized
- physical stock count recorded as a variance movement
- atomic count-and-adjust transaction to prevent sale/count races
- low-stock reorder levels
- healthy / low / out / negative stock states
- action-oriented Stock screen
- receive, count, damaged, lost and low-stock alert workflows
- durable sync outbox for non-sale stock movements
- tenant-safe server stock view using invoker security
- backend, domain, persistence and quantity-parsing regression tests

## Data integrity model

Current stock is derived from the movement ledger. It is never silently overwritten.

A physical count does not rewrite history. It computes the difference between the ledger-derived quantity and the counted quantity, then creates an adjustment movement with a reason.

Sale finalization writes its sale-linked stock movement in the same local transaction as the sale and payment. The sale is the authoritative synchronization source for those sale movements so a future server sync implementation must not independently double-post them.

## Offline model

Receive/count/damage/loss movements are persisted locally and queued in the sync outbox with idempotency keys.

Core store operations remain usable without internet. A negative stock balance is allowed as an observable anomaly rather than silently corrected or blocking billing.

## Security and tenancy

Server stock records carry organization/business/store scope and tenant RLS. The `stock_on_hand` view uses invoker security so it does not bypass the caller's row-level security context.

## UX

Stock uses plain-language status:
- "24 available"
- "Only 6 left — buy more"
- "Out of stock — buy more"
- "Stock is below zero — check count"

The screen exposes only concrete worker actions rather than ERP inventory terminology.

## Explicit follow-up boundaries

Not claimed in V1.2:
- supplier purchase-order generation
- inter-store transfer UI
- camera-assisted stock count
- hardware scanner certification
- production-authenticated inventory synchronization
- advanced forecasting or purchase recommendations

These belong to later roadmap milestones.
