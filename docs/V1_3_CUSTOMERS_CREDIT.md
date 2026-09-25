# V1.3 — Customers and Customer Credit

## Scope

V1.3 adds lightweight customer profiles and makes informal customer credit (udhar / Pay Later) a first-class, auditable workflow.

Implemented:
- optional customer association on cash sales
- guest checkout remains the default fast path
- local customer creation with optional mobile number
- communication-consent field prepared for future messaging
- Customer Credit / Pay Later as a distinct settlement method
- Pay Later available only after selecting a customer
- configurable due date choices during credit checkout
- credit charge recorded atomically with the sale
- immutable customer-credit ledger
- partial cash collection
- over-collection protection
- customer balance, overdue amount, last purchase and statement history
- Customers top-level screen
- server customer/credit schema with tenant RLS
- tenant-safe customer balance view
- backend, payment, domain and SQLite regression tests

## Financial integrity

A credit sale does not edit an account balance field directly. It appends a charge linked to the sale. Later collections append separate payment entries.

The original credit sale remains unchanged. Partial payments reduce the derived balance without altering sale history.

A collection greater than the outstanding balance is rejected.

## Offline behavior

Credit sales and cash collections work against the local durable database.

The credit charge is committed in the same transaction as the sale, stock movement, payment allocation and sale outbox. This prevents a finalized Pay Later sale from existing without its matching credit obligation.

Standalone collections create their own durable sync-outbox entry.

## Customer experience

Customer creation is never required for normal guest checkout.

The Customers screen shows plain-language information such as:
- ₹850 due
- ₹550 overdue
- last purchase date
- payment / credit-sale statement history

## Payment model

Customer Credit is a settlement method but not a payment-provider transaction. It never requires UPI/card provider evidence.

Cash, UPI and Card remain separate payment methods. UPI/Card still require configured provider adapters before use.

## Explicit follow-up boundaries

Not claimed in V1.3:
- SMS/WhatsApp reminders
- loyalty
- marketing campaigns
- production-authenticated customer synchronization
- UPI/card customer-credit collection
- advanced customer segmentation
- consent-policy certification

Those remain later roadmap work.
