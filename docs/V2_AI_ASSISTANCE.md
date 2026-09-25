# V2 — AI Assistance

## Scope

V2 adds an action-oriented Business Assistant without making AI part of core POS correctness.

Implemented:
- local natural-language business questions
- Daily Business Summary
- sales comparison insight
- inventory / purchase suggestions
- customer win-back candidates
- cash-variance anomaly insight
- evidence attached to every generated insight
- explicit Fact / Calculated / Prediction / Recommendation labels
- "Why this answer?" evidence UI
- premium Assistant entry on Home
- optional external AI explanation adapter
- server AI-insight persistence model with tenant isolation
- backend and Flutter regression tests

## Supported local questions

Examples:
- "How much did I sell today?"
- "Show low stock."
- "How much do customers owe?"
- "How much does Ramesh owe?"
- "What are today's expenses?"
- "What is the latest cash difference?"
- "What should I order?"

These queries use deterministic local data access. They work without internet or an AI provider.

## Purchase suggestions

Purchase suggestions use:
- stock currently on hand
- quantity sold during the last 14 days
- average daily quantity sold
- a 7-day target coverage window

The result is labelled **Recommendation**. The evidence shows on-hand stock, recent sold quantity and the target window.

This is not represented as a guarantee of future demand.

## Customer win-back

A candidate is surfaced only when:
- the customer has at least two recorded purchases, and
- the latest recorded purchase is more than 30 days old.

Campaign sending is not performed automatically. Consent/channel enforcement remains a separate requirement.

## Anomaly detection

The repository-achievable V2 foundation currently identifies deterministic exceptions such as:
- significant cash variance
- material sales change versus the comparable prior period
- purchase/stock coverage exceptions

V2.1 adds the return/refund transaction ledger and deterministic refund-activity anomaly detection with inspectable evidence.

## AI safety and data integrity

AI never:
- calculates tax
- finalizes sales
- changes stock directly
- changes permissions
- changes financial history
- authorizes refunds
- fabricates transactions

Every important insight carries source evidence.

External AI is behind an adapter and is unconfigured by default. If later enabled, it receives structured facts/evidence for explanation; deterministic application logic remains authoritative.

## Cost control

The current assistant requires no paid AI inference for its core functions.

Future external-AI use can be limited to explanation or natural-language interpretation, with cached/reused results where safe.

## Explicit follow-up boundaries

Not claimed in V2:
- production LLM provider
- voice speech-to-text provider
- autonomous financial actions
- production campaign sending
- ML forecasting model certification
- cross-store AI aggregation

Those remain later expansion/integration work.
