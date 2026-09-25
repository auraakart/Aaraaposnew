# AaraaPOS V0 Baseline

Status: foundation baseline

## 1. Product requirements baseline

AaraaPOS is a modern, affordable, AI-assisted, offline-first POS and business-management platform for Indian small and medium businesses. It is optimized first for independent stores while preserving clean expansion paths to multi-store use.

Product promise: a first-time employee should be able to begin billing within 5–10 minutes. The cashier mental model is **Sell → choose what the customer buys → Pay**.

Core priorities are simplicity, reliability, speed, offline operation, security, Indian business requirements, low infrastructure cost, maintainability, accessibility and progressive scalability. Billing, tax, stock accounting, payments and permissions are deterministic. AI is optional and advisory.

## 2. Personas and permission matrix

| Capability | Owner | Manager | Cashier | Stock worker |
|---|---:|---:|---:|---:|
| Sell / take payment | Allow | Allow | Allow | No |
| Discount within assigned limit | Allow | Policy | Policy | No |
| High-value refund | Allow | Policy | No | No |
| Receive/count stock | Allow | Allow | No | Allow |
| Stock adjustment | Allow | Policy | No | Policy |
| Customer credit | Allow | Allow | Policy | No |
| Expenses | Allow | Allow | Policy | No |
| Shift management | Allow | Allow | Allow | No |
| Employee/role management | Allow | Policy | No | No |
| Financial/tax configuration | Allow | No | No | No |
| Audit history | Allow | Read | No | No |
| Owner intelligence/profit | Allow | Read | No | No |

Permissions are enforced server-side within organization/business/store scope. UI hiding is never the security boundary.

## 3. Screen map and primary workflows

Primary navigation: **Home, Sell, Stock, Customers, More**. Owner Home is **Business Today**; Cashier default is **Sell**.

Fast sale: Sell → add product by barcode/grid/search/voice/recent → adjust cart → Pay → Cash/UPI/Card/Credit → receipt → New sale.

Offline sale: Sell offline → durable local transaction/event → local receipt → queued sync → reconnect → idempotent synchronization → explicit conflict/rejection handling.

Return/refund: Find bill → select item and quantity → reason → permission/approval → refund method → linked reversal/refund record.

Customer credit: associate customer → Pay Later → amount/due date → immutable credit ledger entry → partial/full collection history.

Shift close: count cash → compare expected/actual → record variance → approval where policy requires → close.

## 4. Technical architecture

Start with a TypeScript modular monolith and explicit domain boundaries: Identity, Organization, Store, Employee, Product, Inventory, Sales, Payment, Customer, Supplier, Purchase, Expense, Tax, Reporting, Notification, Audit and AI.

POS client is Flutter, Android-first with future iOS/tablet support. PostgreSQL is authoritative server storage. Provider-specific payment, messaging, accounting, tax, AI and hardware SDKs remain behind adapters.

Do not add Kubernetes, Kafka, Elasticsearch, Redis or queues until a concrete use case justifies them.

## 5. Offline and synchronization architecture

Every syncable record carries a globally unique ID, organization/business/store/terminal scope, idempotency key, creation time, schema version and sync state.

Conflict classes:
- append-only financial event: never last-write-wins
- inventory movement: append movement and recompute/validate balance
- master data: field-aware merge or user resolution
- configuration/security: server authoritative; stale write rejected

Lifecycle: Pending → Sending → Acknowledged, Conflict or Rejected. Local evidence is retained until acknowledgement.

## 6. Security and multi-tenant architecture

Hierarchy: Organization → Business → Store → Terminal → User relationship.

The server derives authorized tenant/store scope from the authenticated principal and server-side relationships; it never trusts a client-supplied tenant ID alone.

Baseline controls: authentication abstraction, centralized RBAC, least privilege, tenant columns, row-level-security-ready PostgreSQL policies, audit trails, secret isolation, encrypted transport in production, rate limiting where appropriate, secure credential storage, dependency scanning and no unnecessary card data.

Historical financial records are corrected with linked reversal/correction records rather than destructive edits.

## 7. Database/domain model

UUID identifiers support offline creation. Money uses integer minor units or precise decimal types, never binary floating point.

A finalized Sale contains immutable SaleLine, applied tax detail and linked Payment records. Refund/reversal records reference originals. Customer credit uses a ledger. Inventory is append-oriented through receipt, sale, return, adjustment, damage/loss and transfer movements.

Core hierarchy: Organization → Business → Store → Terminal; users receive scoped role assignments.

## 8. API boundaries

V0 exposes only health/status while business modules mature. Future first-party APIs use JSON over HTTPS, authenticated scope, stable validation codes, correlation IDs and idempotency keys on replayable writes.

Planned boundaries: identity, organizations, stores, employees, products, inventory, sales, payments, customers, suppliers, purchases, expenses, tax, reports, audit and AI.

## 9. Repository structure

```text
apps/pos_mobile/
services/api/
  db/migrations/
docs/
.github/workflows/
```

Shared packages are introduced only after two real consumers justify them. Business domain code must not directly depend on hardware/provider SDKs.

## 10. Design system

One screen = one primary decision. Routine work should take roughly three taps after entering a workflow.

Use minimum 48 logical-pixel touch targets, large totals, clear text+icon states, calm spacing, simple navigation, translated strings that can expand, large-text support and no color-only meaning.

Use everyday language such as “Money customers owe” and “Items running out”.

## 11. Milestone roadmap

V0 Foundation → V1 Sell → V1.1 Payments → V1.2 Inventory → V1.3 Customers/Credit → V1.4 Purchases → V1.5 Operations → V1.6 Owner Intelligence → V2 AI Assistance → V2.x Expansion.

Each milestone must pass its quality gates before the next becomes integration-ready.

## 12. Testing strategy

Unit: pricing, discounts, tax, money, stock, permissions and sync policies.

Integration: sale, payment, inventory effect, return/refund, purchase receipt, credit and sync.

E2E: Login → Sell → Pay → Receipt; Offline sale → reconnect → sync; Sale → Return → Refund.

Security: tenant isolation, privilege escalation, unauthorized APIs, malformed input and authentication failures.

Every fixed defect receives a regression test at the lowest useful layer.

## 13. CI/CD strategy

Pull requests to develop/main must run TypeScript typecheck/tests, Flutter analyze/tests and foundation documentation checks. Future gates add dependency/security scans, PostgreSQL migration tests, integration/E2E checks and Android build artifacts.

Main is stable/release-quality. Develop is integrated development. Feature/fix branches are short-lived and merge only when green.

## 14. Risk register

| Risk | Impact | Foundation control |
|---|---|---|
| Duplicate offline financial submission | High | UUID + idempotency contract |
| Cross-tenant leakage | Critical | server authz contract + scoped schema + tests |
| GST/regulatory drift | High | configurable/versioned tax architecture; external validation |
| Low-end Android performance | High | lean Flutter UI; profile on real devices |
| Hardware variability | Medium | adapter boundary |
| Excess infrastructure cost | Medium | modular monolith; progressive scaling |
| AI fabrication | High | advisory-only AI with provenance |
| Data loss before sync | Critical | pending/acknowledged lifecycle |
| Role escalation | Critical | centralized authorization + security tests |
| Localization breakage | Medium | externalizable strings and expansion-safe layouts |

## 15. Definition of Done

A feature is complete only when the user workflow works, errors are handled, offline implications are deliberate, permissions are enforced server-side, audit needs are addressed, tests exist and pass, security is reviewed, UI follows simplicity/accessibility standards and documentation matches implementation.

Milestone completion additionally requires build/typecheck, static analysis, relevant unit/integration/E2E/security checks, no known critical regression, reviewed migrations and updated release documentation.

## External validation boundary

V0 does not claim production payment integrations, production AI, tax-filing gateways, physical-device certification, production credentials, production hosting or regulatory certification.
