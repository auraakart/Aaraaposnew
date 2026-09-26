# V2.13 — Tax Governance Foundation

## Purpose

V2.13 improves tax auditability without hard-coding current Indian GST rules.

AaraaPOS continues to calculate deterministic tax amounts, but now it can preserve the configuration evidence needed to explain which rule/classification was applied to a historical sale.

## Versioned tax rules

The server tax contract supports:
- tenant/business scope
- stable rule key
- explicit version
- HSN/SAC/other classification type
- classification code
- configurable tax rate in basis points
- inclusive/exclusive price mode
- effective-from/effective-to dates
- active/retired status

Rules are selected using the transaction timestamp.

If more than one active rule overlaps for the same business/rule key at the transaction time, resolution fails rather than selecting arbitrarily.

## No hard-coded GST rates

V2.13 deliberately does not encode current statutory GST rates into application constants.

Tax rates remain configuration data.

Actual production tax configuration must be independently verified against then-current Indian requirements before release/use.

## Server persistence

Migration `0019_tax_governance.sql` adds:
- `tax_rule_version`
- product references/classification fields
- immutable tax evidence fields on `sale_line`

Existing historical rows are preserved with nullable snapshot fields rather than backfilled from current product data, because current product settings may not represent what was used historically.

Tenant RLS applies to tax-rule versions.

## Offline product model

Products may now carry:
- tax classification type
- tax classification code
- tax-rule version ID

Classification type/code must be supplied together.

The classification code format is intentionally generic and does not claim statutory validation.

## Immutable sale snapshots

Every new local finalized sale snapshots:
- tax rate basis points
- inclusive/exclusive price mode
- classification type
- classification code
- tax-rule version ID

This evidence is copied onto the sale line.

Changing product tax configuration later does not rewrite historical sale-line evidence.

## Hold/resume integrity

Held bills also retain tax classification and tax-rule references.

This prevents a held/resumed bill from losing tax governance evidence before finalization.

## Audit read path

The local database exposes sale tax snapshots separately from mutable product configuration.

A snapshot is considered fully traceable when rate, price mode, classification and tax-rule version evidence are all present.

Older historical rows created before V2.13 may be partially traceable because V2.13 does not invent missing historical evidence.

## Testing

Backend tests cover:
- effective rule selection by time
- overlapping-rule rejection
- cross-business rule isolation
- immutable tax snapshot creation
- configurable/non-hard-coded rates

Flutter/database tests cover:
- product classification validation
- finalized sale tax evidence
- hold/resume preservation
- auditable snapshot read path

## External boundary

Not claimed:
- legal validation of current GST rates
- HSN/SAC correctness certification
- GST return filing
- e-invoice/e-way-bill integration
- tax-registration eligibility determination
- tax advice
- government portal integration
- historical backfill accuracy for pre-V2.13 transactions

Those require current regulatory verification and/or external integrations.
