# V1.1 — Payments

## Objective

Extend the proven V1 cash path with safe provider abstractions, split-tender rules and reconciliation foundations without fabricating external payment success.

## Implemented

### Payment methods

Domain support exists for:
- Cash
- UPI
- Card

Cash remains available offline and fully functional.

UPI and Card are represented through `ExternalPaymentAdapter` contracts. A provider must explicitly report availability before it can be used. No production provider is configured in this repository milestone.

### Split payments

The payment domain accepts multiple allocations and enforces:
- at least one allocation
- every allocation is a positive integer number of paise
- allocations must sum exactly to the sale total
- every allocation must be captured before a sale can be finalized
- captured UPI/Card allocations require provider identity and provider reference

These rules are deterministic and do not depend on AI or network heuristics.

### Provider orchestration

`PaymentCoordinator`:
- discovers available configured adapters
- always exposes Cash
- initiates external provider flows only through a configured adapter
- converts provider results into normalized payment allocations
- does not accept card credentials or regulated payment secrets

### Reconciliation

A reconciliation rule compares:
- expected local amount
- provider-reported amount
- local payment state
- provider payment state

Only equal captured amounts are marked `matched`; differences become `mismatch`.

### Persistence and audit

Server migration `0003_payments.sql`:
- expands Payment to Cash/UPI/Card
- records provider and provider reference
- records payment status
- records reconciliation status
- requires provider evidence for captured external payments
- creates append-only `payment_event`
- keeps tenant row-level isolation

Local SQLite schema version 2:
- adds provider/status/reconciliation columns
- creates local `payment_event`
- records a captured event for each completed cash payment
- migrates existing V1 databases safely

### User experience

Checkout now first asks:
**How did the customer pay?**

Cash is available immediately.

UPI/Card remain visible but non-actionable with plain-language setup messages until a provider is configured.

Split payment remains non-actionable until at least two usable payment methods exist.

This prevents the interface from implying that money was collected when no provider evidence exists.

## Security decisions

- No PAN/card number/CVV fields are present.
- No external payment is marked captured merely because the cashier taps a button.
- Provider references are treated as evidence identifiers, not secrets.
- Financial payment events are append-oriented.
- Tenant scope remains server-enforced.

## Tests

Backend tests cover:
- exact split allocation totals
- provider evidence for captured UPI/Card
- finalization only after all allocations are captured
- reconciliation match/mismatch
- sanitized audit projections

Flutter tests cover:
- equivalent split/reconciliation rules
- unconfigured provider behavior
- provider coordinator availability/evidence
- disabled UPI/Card/Split user states
- local payment-event persistence for cash

## External integration boundary

Requires external validation/integration:
- production UPI gateway
- production card/acquirer gateway
- provider webhooks/callback verification
- real reconciliation feeds
- PCI/payment-provider compliance validation
- physical payment terminal testing

None of those are claimed as implemented.
