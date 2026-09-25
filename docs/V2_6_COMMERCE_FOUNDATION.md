# V2.6 — Commerce / WhatsApp-Ready Order Foundation

## Purpose

V2.6 adds a provider-neutral customer-order workflow for orders received through channels such as WhatsApp or phone without making an external messaging provider a dependency of billing.

A commerce order is **pre-sale intent**.

Creating, confirming or preparing an order does not create:
- revenue
- payment
- customer credit
- stock movement
- invoice history

Only the existing AaraaPOS Sell workflow can create the financial sale.

## Order lifecycle

Supported order states:

Received → Confirmed → Ready → Completed

Before completion, an order may be cancelled from:
- Received
- Confirmed
- Ready

Completed orders must link to a real finalized Sale.

A completed or cancelled order cannot be re-opened through ordinary state transitions.

## Channels

The domain supports:
- WhatsApp
- Web
- Phone
- Manual

The current POS UI provides manual capture for:
- WhatsApp orders received outside AaraaPOS
- Phone orders
- Manual/in-person pre-orders

Web is retained as a provider/API-ready channel but no storefront is claimed.

## POS workflow

More → Commerce Orders provides:
- order capture
- optional customer link
- optional WhatsApp conversation/reference
- multiple products and quantities
- quoted order value
- note
- Confirm
- Mark ready
- Cancel
- Bill order

Bill order loads the order into the **existing Sell screen**.

The normal POS sale pipeline still controls:
- current product price
- tax
- discounts/offers
- customer association
- payment
- receipt
- stock movement
- loyalty
- audit
- synchronization

After successful payment/finalization, the commerce order is linked to that exact Sale and marked Completed.

The Sell screen then returns to the commerce queue so the same order cannot accidentally be billed again as a second “new sale”.

## Price semantics

Commerce order lines retain the quoted unit price captured with the order.

That quoted value is evidence of what the order looked like when captured.

Final checkout uses the normal POS Product/Sell pricing path rather than trusting an external channel to authoritatively set financial amounts.

A future provider flow may add explicit price-lock policy, approval or customer reconfirmation. V2.6 does not silently override POS pricing.

## Customer consent and WhatsApp

A customer record already carries communication consent:
- unknown
- opted in
- opted out

The commerce domain permits a proactive WhatsApp message only when:
1. the channel is WhatsApp,
2. a real provider is configured, and
3. the customer is explicitly opted in.

Manual recording of an order that the customer already sent does not claim that AaraaPOS itself sent or received the WhatsApp message.

## Inbound provider contract

Server persistence supports inbound commerce evidence with:
- provider event ID
- provider/configuration reference
- channel
- external conversation reference
- payload hash
- signature-valid flag
- timestamp-valid flag
- processing state
- optional created commerce-order link

Provider event IDs are intended to be idempotent/deduplicated.

Actual signature verification and replay protection use the V2.4 integration contracts.

## RBAC

Commerce permissions are explicit:
- Owner: manage
- Manager: manage
- Cashier: manage
- Stock Worker: no commerce management

Server-side authorization remains the authoritative security boundary for authenticated integrations.

## Offline behavior

Manual order capture is stored locally and queued in the existing outbox.

The store can capture and later bill manual phone/WhatsApp orders without internet.

Automated inbound WhatsApp/web orders require server/provider connectivity and are not simulated locally.

## Testing

Backend tests cover:
- order-state transitions
- invalid status skips
- sale-intent conversion
- proactive WhatsApp consent/provider requirements
- inbound event dedupe keys
- commerce RBAC

Flutter tests cover:
- matching local lifecycle rules
- consent behavior
- commerce order remains pre-sale
- multi-item order → normal Sell finalization → exact Sale linkage
- cancelled order cannot be linked to a later sale

## External boundary

Not claimed in V2.6:
- WhatsApp Business provider connection
- Meta/provider credentials
- webhook endpoint registration
- WhatsApp template approval
- automated inbound parsing
- automated outbound delivery
- web storefront
- payment links
- delivery/fleet logistics
- production spam/opt-out compliance validation

Those require real providers, credentials and deployment.
