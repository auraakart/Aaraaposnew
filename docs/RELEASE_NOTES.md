# Release Notes

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
