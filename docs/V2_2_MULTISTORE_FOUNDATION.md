# V2.2 — Multi-store Foundation

## Purpose

V2.2 extends AaraaPOS from an independent-store architecture to a safe multi-store foundation without weakening offline transaction isolation.

## Core rule

A physical/offline POS terminal remains bound to **one store**.

Offline billing, stock, shifts and cash on that terminal never switch stores by changing a UI filter. This prevents cross-store contamination when the network is unavailable.

Multi-store owner views, remote store access and destination-store receipt require authenticated server synchronization.

## Implemented

### Store authorization
- explicit store read permission
- transfer create permission
- transfer receive permission
- cashier cannot execute transfers
- owner / manager / authorized stock worker can transfer only within assigned stores
- a transfer requires access to both source and destination stores
- cross-business and cross-organization transfer is rejected

### Database scope
- active store state
- user/store access assignments
- organization/business/store composite scope constraints
- source and destination store scope enforced by database foreign keys
- tenant RLS on access and transfer records

### Inter-store transfer
Transfer lifecycle:
1. draft
2. dispatched
3. received

A draft may be cancelled before dispatch.

Dispatch produces an append-only:
- `transfer_out` movement for the source store

Receipt produces the paired:
- `transfer_in` movement for the destination store

The original transfer remains the common source entity for both events.

Invalid transitions are rejected. A received transfer cannot be silently cancelled or rewritten.

### Multi-store reporting foundation
The server domain can aggregate authorized store metrics while preserving each store's individual contribution.

Current aggregate fields:
- sales
- bill count
- expenses
- refunds

### POS UX
More → Store & Terminal shows:
- current store
- terminal
- offline one-store binding
- transfer semantics
- the authenticated-sync boundary for other stores

## Security

The client does not decide authoritative tenant/store identity.

Service authorization validates:
- organization
- business
- source store
- destination store
- permission

The PostgreSQL schema also prevents a transfer from referencing stores that do not belong to the declared organization/business.

## Offline behavior

The local terminal database remains store-specific. This is intentional.

A source store may continue normal billing when offline. Cross-store dispatch/receipt requires an authenticated synchronization path before it can safely coordinate two stores.

AaraaPOS does **not** copy every store's financial database onto every POS terminal.

## Explicit external/future boundary

Not claimed in V2.2:
- production authentication/session integration
- real server synchronization
- live owner cross-store dashboard data
- destination-device push notification
- physical shipment tracking
- cross-business transfer
- centralized warehouse management

Those require deployed server connectivity or broader logistics functionality.
