# V1.5 — Store Operations

## Scope

V1.5 adds the day-to-day operational controls required to run a small store without turning the worker UI into an ERP.

Implemented:
- local employee roster
- owner / manager / cashier / stock-worker role model
- shift open/close
- opening cash
- automatic association of sales with an open shift
- drawer deposits and withdrawals with reasons
- expense capture
- cash expense impact on reconciliation
- customer-credit cash collection association with open shift when available
- expected closing cash calculation
- actual cash count
- immutable variance recording
- approval request when variance exceeds a threshold
- server employee-profile / shift / cash-movement / expense / approval schema
- Store Operations UI from More
- backend and offline persistence regression tests

## Shift reconciliation

Expected closing cash is derived from:

opening cash
+ cash sales
+ cash customer-credit collections associated with the shift
+ drawer deposits
- drawer withdrawals
- cash expenses

Actual closing cash is recorded independently. The difference is stored as the variance; it is never silently changed to make the shift balance.

The initial local threshold for creating a cash-variance approval request is configurable at close time and defaults to ₹500. This is a policy foundation rather than a production organization-wide policy service.

## Employees and security

The local roster stores identity, role and active state only.

V1.5 deliberately does **not** invent or store plaintext PINs/passwords. Production authentication, credential issuance, device trust and session management remain part of the authenticated identity integration boundary.

Server-side authorization continues to use the centralized role/permission model from V0. UI visibility is not the security boundary.

## Expenses

Expense entry remains short:
amount → category → payment method → optional note → save.

Initial categories include Rent, Electricity, Transport, Tea/Food, Maintenance and Other.

Cash expenses during an open shift feed drawer reconciliation. Non-cash expenses remain in business expense history without changing drawer cash.

## Offline behavior

Employees, shifts, drawer movements and expenses persist locally. Syncable operations use durable idempotent outbox records.

Sales continue to work without an open shift for backward compatibility and owner simplicity. When a shift is open they are associated automatically.

## Explicit follow-up boundaries

Not claimed in V1.5:
- production login/PIN provisioning
- biometric/device trust
- payroll/attendance
- real bank expense feeds
- attachment upload/storage
- server-executed approval workflow
- production-authenticated synchronization

These are intentionally separate from the local operational foundation.
