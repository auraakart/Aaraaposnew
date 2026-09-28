# V2.14 — Approval Governance

## Purpose

V2.14 turns AaraaPOS approval records into a usable authorization lifecycle.

Before this milestone, sensitive cashier discounts/refunds could correctly stop with “Manager approval required”, and cash-variance reviews could create pending records, but there was no general request → review → consume workflow.

V2.14 adds that workflow without weakening existing role controls.

## Approval lifecycle

The lifecycle is:

1. **Requested**
2. **Approved** or **Rejected**
3. **Consumed once** when the authorized sensitive action executes

Approval and action execution remain separate records.

Approval does not mutate the financial transaction by itself.

## Separation of duties

Approval resolution is restricted to:
- Owner
- Manager

Cashier and Stock Worker cannot resolve approvals.

The requester cannot resolve their own approval request, even if their role would normally permit approval resolution.

This prevents the same identity from requesting and approving the same exception.

## Action fingerprints

Sensitive approvals can be bound to a deterministic action fingerprint.

For a high-value refund, the fingerprint includes:
- action type
- original sale ID
- selected sale-line ID
- requested quantity
- calculated refund amount

Facts are normalized and sorted before the fingerprint string is created.

An approval for one quantity/amount cannot authorize a different refund.

## One-time consumption

Approved action-bound requests are consumed exactly once.

Consumption requires:
- approved status
- matching action type/entity/fingerprint
- same requester consuming the approval
- approval not expired
- no prior consumption record

Consumption is written in the same local database transaction as the protected refund.

If the refund later fails in that transaction, approval consumption rolls back too.

## Expiry

Action-bound approval requests default to a two-hour validity window.

The local request API restricts validity to a maximum of 24 hours.

Expired requests cannot be newly approved and cannot be consumed.

Rejected and expired approvals never authorize an action.

## High-value refund workflow

For a cashier refund above the configured self-approval threshold:

1. The first attempt is blocked.
2. AaraaPOS creates or reuses a matching pending approval request.
3. The Owner/Manager sees the request in Store Operations.
4. The reviewer approves or rejects it.
5. The cashier retries the exact refund.
6. The approved fingerprint is consumed atomically.
7. The return/refund proceeds through the normal immutable return workflow.

A second identical partial refund cannot reuse the consumed approval.

Owner/Manager refunds remain governed by their existing role permission and do not require this cashier exception workflow.

## Cash-variance review

Existing cash-variance approval requests now appear in the same Owner/Manager review surface.

Cash-variance approval is review evidence for an already-recorded discrepancy; it does not rewrite the shift or silently remove the variance.

## Persistence

Server migration `0020_approval_governance.sql` extends approval requests with:
- action fingerprint
- requested amount
- expiry

It also adds `approval_consumption` with a unique approval-request reference.

Local SQLite schema v14 adds equivalent fields and one-time consumption evidence.

## Audit and synchronization

Repository-achievable approval operations create sync/audit evidence for:
- approval requested
- approval approved/rejected
- approval consumed

Financial history remains separate and immutable.

## Testing

Backend tests cover:
- Owner/Manager resolution
- self-approval rejection
- cashier resolution rejection
- matching fingerprint validation
- expiry
- one-time consumption

Flutter/database tests cover:
- deterministic fingerprint generation
- ambiguous fingerprint rejection
- cashier approval request
- Owner resolution
- successful high-value approved refund
- consumption evidence
- prevention of approval reuse
- cashier resolution denial
- requester self-approval denial

## External boundary

Not claimed:
- remote push notifications for approval requests
- production authenticated server approval APIs
- biometric approval
- delegated approval chains
- enterprise maker-checker policy engines
- regulatory certification

Those require production identity/notification infrastructure or business-specific policy.
