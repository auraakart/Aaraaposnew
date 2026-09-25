# V2.1 — Core Transaction Closure

## Purpose

V2.1 closes the remaining repository-achievable gaps in the core Sell transaction workflow before optional expansion features.

## Implemented

### Returns and refunds
- find refundable bills by invoice/customer
- select returned item and quantity
- reason capture
- partial return support
- strict prevention of over-return
- original sale linkage
- immutable return header and return lines
- tax/totals prorated from the original sale line
- stock restored using append-only `return_in` movement
- cash refund ledger
- Pay Later credit reversal
- automatic split between credit reversal and cash refund when a credit customer already paid part of the debt
- return numbering per terminal
- durable outbox record
- tenant-safe server return/refund schema
- cash refunds included in shift reconciliation
- refunds surfaced in Business Today and business timeline

The original sale remains finalized and unchanged. A full return does not delete or rewrite the sale; the return ledger is the correction evidence.

### Hold and resume
- hold the current bill locally
- preserve product price/tax snapshots
- preserve quantity, discount and customer
- resume and remove the held copy atomically
- no network dependency

Held carts are intentionally local/transient and are not financial records until finalized.

### Discounts
- line discount entry in Sell
- deterministic discount pricing
- cashier self-approval threshold hook
- manager/owner bypass according to role
- stock workers cannot self-authorize financial discounts

The current local bootstrap session is the owner. Production employee-session authentication remains an external identity integration boundary.

### Barcode scanning
- camera barcode screen using `mobile_scanner`
- barcode result routes through the existing local product lookup
- manual/search/wedge-scanner flow still works when camera scanning is unavailable

Physical-device camera validation remains external.

### Receipts
- copy receipt
- platform share receipt
- printer adapter contract
- unconfigured printer adapter fails explicitly rather than pretending to print

Physical printer SDK integration/certification remains external.

### AI / reporting
- refund total is visible in Business Today
- returns appear in the business timeline
- assistant answers refund/return questions from recorded facts
- deterministic refund-activity anomaly insight uses inspectable evidence

Estimated profit is withheld for periods containing refunds until return COGS reconciliation is modeled completely. This avoids fabricating profit.

## Data integrity

Return quantity is validated against:

original sold quantity
- already finalized returned quantity

A Pay Later return derives the remaining unpaid amount for that original sale using the existing FIFO customer-credit allocation model. The refund is then split:

unpaid portion → customer-credit correction
already-paid portion → cash refund

This prevents both over-crediting and refunding money that was never paid.

## External boundaries

Not claimed:
- physical printer certification
- production camera permission/device validation
- production UPI/card refund provider integration
- server-executed manager approval workflow
- statutory credit-note/e-invoice provider filing
- production-authenticated synchronization

These require real providers, credentials, regulated flows, or physical-device validation.
