# V1.6 — Owner Intelligence

## Scope

V1.6 turns Home into an owner-oriented Business Today control centre while keeping recorded facts separate from estimates.

Implemented:
- Today / Yesterday / This Week / This Month reporting
- sales
- bill count
- money received
- customer money due
- expenses
- estimated profit when cost coverage is complete
- purchase-cost coverage indicator
- low-stock exception count
- latest cash-variance alert
- sales comparison with the same period one week earlier
- chronological business timeline
- proactive data-quality checks
- backend reporting domain and indexes
- Flutter owner dashboard and regression tests

## Profit integrity

Estimated profit is **not** revenue minus expense.

For sold items, AaraaPOS looks for a recorded purchase cost available before the sale. Estimated profit is shown only when all taxable sales in the selected period have cost coverage:

taxable sales
- estimated product cost
- recorded expenses

If any sold item lacks cost history, the dashboard displays **Need cost data** with the coverage percentage instead of inventing a profit number.

This remains an operational estimate, not statutory accounting profit.

## Business timeline

The timeline tells the business-day story using recorded events such as:
- sale
- expense
- stock receipt
- customer credit creation
- shift opening
- shift closing / cash difference

It is derived from source records rather than a generic activity feed.

## Data quality

Initial checks detect:
- duplicate product names
- zero/missing selling prices
- negative stock
- duplicate customer mobile numbers
- suppliers missing both contact and GSTIN

Each issue includes a plain-language repair hint.

## Performance

Reporting queries have server-side index support for sales, payments, expenses, customer-credit entries, purchase-cost lookup and closed shifts.

The local dashboard stays deterministic and does not require AI or internet.

## Explicit follow-up boundaries

Not claimed in V1.6:
- statutory P&L
- accounting depreciation
- production tax filing
- server-hosted analytics warehouse
- cross-store consolidated reporting
- forecasting
- anomaly ML

Forecasting and recommendation logic belongs to V2 AI Assistance and must remain clearly labelled as prediction/recommendation.
