# V2.16 — Role-Aware Workspace

## Purpose

V2.16 aligns the POS workspace with the authenticated employee role introduced in V2.15.

The goal is **least-privilege UX**:

- show each role the destinations they need most,
- remove distracting or irrelevant administrative surfaces,
- preserve simple role-specific starting points,
- keep server/database authorization as the true security boundary.

Hiding a screen does not grant or revoke permission by itself.

## Primary navigation

### Owner

- Home
- Sell
- Stock
- Customers
- More

Default: Home / Business Today.

### Manager

- Home
- Sell
- Stock
- Customers
- More

Default: Home / Business Today.

### Cashier

- Sell
- Customers
- More

Default: Sell.

Cashiers do not see Home/owner intelligence or Stock as persistent destinations.

### Stock Worker

- Stock
- More

Default: Stock.

Stock Workers do not see Home, Sell or Customers as persistent destinations.

## More menu

A single role policy also controls the More menu.

### Owner / Manager

Full repository-achievable More workspace:

- Employee Access
- Recovery Readiness
- Diagnostics
- Audit History
- Language & Accessibility
- Hardware & Devices
- Commerce Orders
- Accounting Export
- Integrations & Sync
- Loyalty & Offers
- Store & Terminal
- Returns & Refunds
- Store Operations
- Purchases & Suppliers

Individual actions inside these screens remain subject to their existing role/database rules.

### Cashier

Visible:

- Language & Accessibility
- Hardware & Devices
- Commerce Orders
- Returns & Refunds
- Store Operations

Hidden:

- Employee Access
- Recovery Readiness
- Diagnostics
- Audit History
- Accounting Export
- Integrations & Sync
- Loyalty & Offers
- Store & Terminal
- Purchases & Suppliers

The Cashier still relies on existing approval governance for restricted refund/financial actions.

### Stock Worker

Visible:

- Language & Accessibility
- Hardware & Devices
- Store & Terminal

Hidden:

- Employee Access
- Recovery Readiness
- Diagnostics
- Audit History
- Commerce Orders
- Accounting Export
- Integrations & Sync
- Loyalty & Offers
- Returns & Refunds
- Store Operations
- Purchases & Suppliers

Stock operations remain available through the Stock destination and existing inventory authorization.

## Architecture

`workspace_policy.dart` is the single client-side source for:

- allowed primary destinations,
- allowed More features,
- role default destination.

The shell and More screen consume that policy rather than duplicating role conditionals across widgets.

This reduces drift between navigation and secondary surfaces.

## Security boundary

V2.16 is UX hardening, not a replacement for authorization.

The authoritative controls remain:

- authenticated employee/session identity,
- local database role checks,
- approval governance,
- server-side RBAC and tenant/store scope.

A future deep link, restored route or API call must still be denied if authorization is absent even when the UI normally hides the entry point.

## Testing

Policy tests cover:

- full Owner/Manager workspace,
- Cashier default and hidden admin/accounting destinations,
- Stock Worker minimal workspace.

Widget tests cover:

- Cashier More menu rendering,
- Stock Worker More menu rendering,
- absence of administrative/accounting cards for restricted roles.

## External boundary

Not claimed in V2.16:

- enterprise entitlement engine,
- custom per-employee feature toggles,
- remote policy administration,
- attribute-based access control,
- dynamic server-delivered navigation,
- deep-link authorization middleware for production routing.

Those can be added later without changing the principle that UI visibility is not the security boundary.
