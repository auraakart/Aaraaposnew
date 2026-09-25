# V2.5 — Accounting & Export Foundation

## Purpose

V2.5 turns AaraaPOS transaction data into portable, source-linked business registers without pretending to be a certified accounting system or statutory GST filing engine.

The export is generated from existing immutable/append-oriented records. It does not create parallel financial truth.

## Registers

The local Accounting Export includes:
- sales
- returns
- purchases
- expenses
- customer-credit activity
- supplier-ledger activity

Each row carries:
- register type
- source record ID
- document/reference number where available
- occurrence timestamp
- party
- description
- balance effect: increase/decrease
- gross amount
- discount
- tax fields
- total amount
- payment method where applicable
- source status

This lets downstream systems trace every export row back to AaraaPOS evidence.

## Tax treatment

### Sales and returns

Sales and return lines already store:
- taxable amount
- CGST
- SGST
- IGST
- total

Exports preserve those exact recorded values.

The UI shows:
- sales taxable value
- return taxable value
- sales CGST/SGST/IGST after recorded returns

A return is never silently netted into the original sale record.

### Purchases

Current purchase receipts store:
- line total
- total purchase tax

They do not yet store a CGST/SGST/IGST split.

V2.5 therefore exports purchase tax as:
**unclassified purchase tax**

It does not guess a split.

Future purchase-tax schema can add component detail without changing the source-linked export model.

### Expenses and settlement ledgers

Expense rows, customer-credit movements and supplier-ledger movements are amount records. V2.5 does not fabricate GST fields for them.

## CSV safety

CSV export:
- uses two-decimal rupee values
- quotes all fields
- removes embedded line breaks
- escapes embedded quotes
- neutralizes spreadsheet formula prefixes (=, +, -, @)

This reduces CSV/spreadsheet injection risk when names or notes originate from user-entered data.

## User experience

More → Accounting Export provides:
- Today
- Yesterday
- This Week
- This Month
- sales/returns/purchases/expenses summary
- output-GST-after-returns summary
- explicit purchase-tax uncertainty
- source-linked register preview
- copy CSV
- system share CSV

The core POS does not depend on export availability.

## Server integration foundation

Migration `0014_accounting_exports.sql` adds auditable export batches:
- organization/business/store scope
- period
- format
- row count
- content hash
- generated/delivered/failed state
- optional integration provider/reference
- source record membership

This supports later accounting-provider delivery without treating local CSV generation as external delivery.

## Important accounting semantics

Customer Credit and Supplier Ledger exports are **activity registers**, not revenue/expense totals.

Sales and purchase registers remain the primary transaction/tax sources.

AaraaPOS does not derive statutory journals, chart-of-accounts mappings, depreciation, bank reconciliation or final financial statements in this milestone.

## Testing

Backend tests cover:
- row tax arithmetic
- separated sales/return/purchase tax summaries
- CSV formula-injection neutralization

Flutter tests cover:
- equivalent manifest behavior
- decimal CSV output
- source-linked export from a real local sale, return, purchase receipt, expense and supplier ledger
- purchase tax preserved as unclassified when components are unavailable

## External / regulatory boundary

Not claimed:
- GST return filing
- e-invoice filing
- statutory books
- CA/accountant certification
- Tally/Zoho/QuickBooks delivery
- provider credentials
- production accounting reconciliation
- purchase GST component accuracy when the source receipt lacks components

These require current regulatory verification and/or real provider integrations.
