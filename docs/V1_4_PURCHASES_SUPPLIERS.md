# V1.4 — Purchases & Suppliers

## Scope

V1.4 adds a simple, offline-capable replenishment workflow for independent stores.

Implemented:
- supplier creation
- purchase order creation
- purchase order line cost/quantity capture
- receive-order workflow
- stock increase linked to purchase receipt
- supplier payable created from received goods
- purchase return with stock reduction
- supplier credit from purchase return
- partial supplier payment
- outstanding supplier balance
- supplier credit state when returns exceed payable
- durable local outbox records
- server PostgreSQL supplier/order/receipt/return/ledger schema
- tenant RLS and security-invoker balance view
- purchase-return stock movement type
- Purchases & Suppliers UI from More
- backend and SQLite regression tests

## Financial and stock integrity

Purchase orders do not alter stock or supplier balances.

Receiving an order atomically creates:
1. the purchase receipt,
2. receipt lines,
3. stock-in movements,
4. supplier payable ledger entry,
5. the outbound synchronization record.

Purchase returns append separate return and stock-out records. Supplier payments append separate ledger entries. Historical purchase charges are never rewritten.

## Supplier balance

Supplier balance is derived from ledger entries:
- purchase charge increases amount payable
- supplier payment reduces amount payable
- purchase return credit reduces amount payable
- a negative balance means the supplier owes the business / the business has supplier credit

Payments themselves cannot exceed a positive payable balance.

## Offline behavior

Order creation, receiving, returns and cash supplier payments work locally. Sync records are idempotent and queued without making internet availability part of the store workflow.

## UX

The initial workflow uses plain actions:
- Add supplier
- Create order
- Receive
- Record payment
- Return stock

ERP terminology is kept out of the main workflow.

## Explicit follow-up boundaries

Not claimed in V1.4:
- WhatsApp purchase-order sending
- supplier portal
- production bank/UPI payment integration
- invoice OCR
- multi-line order editing UI
- partial receipt UI
- inter-store transfers
- production-authenticated synchronization

The domain and schema are structured so these can be added without rewriting financial history.
