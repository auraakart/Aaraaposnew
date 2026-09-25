# V1 — Sell

## Scope

V1 turns the V0 shell into a locally usable offline cash-billing flow.

Implemented:
- five-minute local business/store bootstrap
- local product creation
- product name/barcode lookup
- simple product-grid selling
- quantity increase/decrease
- weighted-quantity domain representation in milli-units
- deterministic inclusive/exclusive tax math
- intra-state CGST/SGST and inter-state IGST calculation
- integer-minor-unit money handling
- cash checkout with exact/₹500/₹1000/other tender
- automatic change calculation
- local invoice sequence per terminal
- local text receipt
- atomic offline persistence for sale, lines and cash payment
- durable sync outbox record
- server-side product/sale/payment schema
- pricing and offline persistence regression tests

## Affected modules

Flutter POS Sell workflow and local database; TypeScript sales domain; PostgreSQL product/sales schema.

## Data changes

Server migration `0002_sell.sql` introduces product category, product, sale, sale line and cash payment tables with tenant isolation policies.

The local SQLite database stores provisional tenant/store setup, products, terminal invoice sequence, immutable sale records, sale lines, payments and sync outbox entries.

## API boundary

No unauthenticated sale-sync endpoint is exposed in V1. Offline sales are queued locally. Server ingestion will be enabled only when the authenticated synchronization contract is implemented, so the client cannot choose its own authoritative tenant simply by sending tenant IDs.

## UX

The selling flow prioritizes:
1. search/name/barcode input
2. large product cards
3. one-tap add
4. persistent Pay total
5. large cash tender choices
6. clear change due and receipt

## Risks and limitations

- Camera barcode scanning, hold/resume, line discounts, customer association and receipt copy/share were closed in V2.1.
- A printer adapter contract now exists, but physical printer integration/certification remains external validation.
- Local bootstrap creates provisional IDs; online account linking must authenticate ownership before server synchronization.
- Product images remain a later catalogue enhancement rather than a transaction-integrity requirement.
- Tax rates are selectable data, but production GST behavior still requires current regulatory validation.
- Physical printer/scanner certification is external validation.

## Tests

TypeScript tests cover inclusive/exclusive tax, GST split, weighted quantities, total aggregation, discount bounds and cash change.

Flutter tests cover first-run setup/navigation, matching money/tax cases, local invoice sequence, atomic sale persistence and durable outbox creation.

## Definition-of-Done assessment

The core offline cash sale is implemented and testable. The transaction-critical follow-up gaps were explicitly closed in V2.1; external provider, regulatory and physical-device validation remains outside repository-only completion.
