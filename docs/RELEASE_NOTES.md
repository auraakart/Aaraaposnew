# Release Notes

## V1.5 Store Operations — validation

Added employee roster/roles, shift opening/closing, drawer deposits/withdrawals, expenses, sale-to-shift association, deterministic cash reconciliation, variance recording and approval-request foundation.

Production credential issuance, payroll, attendance, bank feeds and server approval execution remain explicit external/future boundaries.

## V1.4 Purchases & Suppliers — validation

Added suppliers, purchase orders, receive-to-stock workflow, purchase returns, supplier payable/credit ledger, bounded supplier payments, Purchases UI, tenant-safe server schema and regression tests.

Not claimed: external supplier messaging, real payment providers, OCR, partial-receipt UI or production-authenticated synchronization.

## V1.3 Customers & Credit — validation

Added optional customer association, Customers navigation, Customer Credit / Pay Later checkout, immutable credit charges, partial cash collection, due dates, overdue/balance summaries, statement history, tenant-safe server schema and regression tests.

Guest checkout remains unchanged and customer creation is not mandatory.

Not claimed in V1.3: production messaging reminders, loyalty, marketing campaigns, provider-backed credit collection or production-authenticated customer synchronization.

## V1.2 Inventory — validation

Added append-only stock movements, database-enforced movement direction, automatic sale stock reduction, atomic stock counts, low-stock thresholds, negative-stock anomaly visibility, offline receive/count/damage/loss workflows, Stock navigation UI, tenant-safe server aggregation and inventory regression tests.

Not claimed in V1.2: supplier ordering, inter-store transfer UI, production-authenticated inventory sync, camera count/scanning certification or AI purchase forecasting.

## V1.1 Payments — validation

Added UPI/Card adapter contracts, provider availability coordination, deterministic split-payment validation, payment finalization rules, reconciliation matching, server and local payment-event ledgers, payment status/provider evidence fields and an explicit payment-method chooser.

Cash remains fully operational. UPI/Card/Split stay disabled in the shipped UI until real providers are configured; no external payment success is simulated.

Production provider integrations, webhook verification, real reconciliation feeds, payment-terminal certification and regulatory/provider compliance validation remain external work.

## V1 Sell — validation

Added deterministic sale pricing, GST split calculation, weighted-quantity representation, first-run local store bootstrap, local product/barcode catalogue, fast cart interaction, cash checkout, local invoice sequencing, text receipts, durable SQLite sale/payment storage, sync outbox creation, server-side sales schema and regression tests.

Still outside the completed V1 core: camera barcode integration, receipt printer/share adapters, hold/resume, customer association and production-authenticated sale synchronization. These remain explicit follow-up gaps and are not claimed complete.

## V0 Foundation

Implemented:
- product/persona/workflow/architecture baseline
- modular-monolith service direction
- offline conflict and idempotency model
- multi-tenant/RBAC security contract
- PostgreSQL organization/business/store/terminal/user/audit foundation
- Flutter POS shell and design primitives
- CI quality gates and initial regression/security tests

Not claimed:
- production payment or AI integrations
- tax filing gateways or regulatory certification
- physical hardware certification
- production credentials, hosting or deployment





