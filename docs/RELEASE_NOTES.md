# Release Notes

## V2.10 Quality & Security Gates — validation

Added migration ordering/destructive-SQL policy checks, dependency-source and committed-secret hygiene checks, PR dependency vulnerability review, and low-noise weekly Dependabot updates for npm/pub.

Android build/signing and full lockfile reproducibility remain explicit repository gaps because the current repository has no Android platform scaffold and no committed npm/pub lockfiles.

# Release Notes

## V2.9 Audit & Governance Foundation — validation

Added append-oriented local audit evidence for critical committed actions, atomic audit/outbox recording, Owner/Manager-only Audit History, server audit validation and sensitive-metadata rejection, terminal/outcome evidence, and regression tests.

Audit remains source-linked evidence; financial and stock ledgers remain authoritative.

# Release Notes

## V2.8 Localization & Accessibility Foundation — validation

Added English/Hindi/Tamil localization infrastructure, persisted offline language preference, localized core navigation and primary Sell actions, a Language & Accessibility screen, device text-scale preservation, planned-language boundaries, and localization/persistence/widget regression tests.

Additional Indian languages remain prepared but intentionally unsupported until translated and reviewed.

# Release Notes

## V2.7 Hardware & Device Foundation — validation

Added terminal-scoped hardware/device capability contracts, server device/profile command-audit schema, provenance rules for drawer/receipt actions, Flutter adapter contracts for drawer/scale/display/payment terminal, truthful readiness UI, and regression tests.

Camera scanning remains app-integrated. Printer/drawer/scale/display/payment-terminal physical integrations and certification remain external.

## V2.6 Commerce / WhatsApp-Ready Foundation — validation

Added provider-neutral commerce orders with channel provenance, manual WhatsApp/phone capture, Received → Confirmed → Ready → Completed lifecycle, explicit RBAC, consent-aware WhatsApp messaging rules, inbound-event persistence, offline order queue, and conversion into the existing Sell/payment pipeline.

Commerce orders remain pre-sale intent; revenue, payment and stock change only through finalized POS sales. No real WhatsApp provider or web storefront is claimed.

## V2.5 Accounting & Export Foundation — validation

Added source-linked sales, returns, purchases, expenses, customer-credit and supplier-ledger registers; separated sales/return/purchase tax summaries; explicit unclassified purchase tax; spreadsheet-safe CSV copy/share; export audit schema; owner Accounting Export UI; and regression tests.

This is a portable business register/export foundation, not statutory accounting, GST filing or a claim of external accounting-provider integration.

## V2.4 Integration Contracts — validation

Added versioned sync envelopes, explicit outbox state transitions, retry metadata, replay/idempotency collision rules, conflict classification, provider capability declarations, HMAC/timestamp webhook verification contracts, tenant-scoped ingestion/provider-event persistence and an owner-visible Integrations & Sync screen.

No production provider, credentials or deployed sync transport is simulated.

## V2.3 Loyalty & Promotions — validation

Added append-only customer loyalty points, owner-configurable earning/redemption rules, point redemption with transaction-time balance validation, return reversal/restoration, deterministic best-offer selection, product/basket promotions, sale-line discount source traceability and Loyalty & Offers UI.

Pay Later loyalty earning remains excluded until authenticated credit-settlement allocation exists; loyalty redemption is limited to tax-inclusive carts for deterministic visible value.

## V2.2 Multi-store Foundation — validation

Added explicit store access permissions, source/destination authorization, database store-scope consistency, inter-store transfer lifecycle/events, multi-store aggregation domain and a Store & Terminal scope screen.

Offline POS terminals remain deliberately store-bound; production authenticated cross-store synchronization is not simulated.

## V2.1 Core Transaction Closure — validation

Added partial returns/refunds with immutable original-sale linkage, Pay Later credit/cash split refunds, stock restoration, shift-aware cash refunds, hold/resume, line discounts with authorization rules, camera barcode scan UI, receipt copy/share adapters, refund reporting and refund anomaly intelligence.

Original finalized sales are preserved; returns are separate correction records.

Physical printer/camera certification, external provider refunds and production approval execution remain external boundaries.

## V2 AI Assistance — validation

Added an offline evidence-backed Business Assistant, daily summary, sales comparison, purchase suggestions, customer win-back candidates and cash anomaly insights. Every important insight is labelled as fact/calculation/prediction/recommendation and exposes supporting evidence.

No production external AI provider or autonomous financial action is claimed.

## V1.6 Owner Intelligence — validation

Home now provides period-based sales, bills, receipts, customer dues, expenses, guarded estimated profit, low-stock/cash exceptions, a business timeline and actionable data-quality checks.

Estimated profit is intentionally withheld when recorded purchase-cost coverage is incomplete.

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

















