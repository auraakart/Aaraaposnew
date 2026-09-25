# V2.3 — Loyalty & Promotions

## Purpose

V2.3 adds simple, transparent retention tools without making checkout harder or allowing promotions to corrupt pricing history.

## Loyalty

Implemented:
- owner-configurable enable/disable
- points earned per ₹100
- configurable discount value per point
- configurable maximum redemption percentage
- append-only customer loyalty ledger
- points visible on customer profiles and customer selection
- points earned on settled local cash sales
- point redemption from Sell
- no stacking with another discount
- redemption only on tax-inclusive carts in this milestone
- balance revalidation inside the sale transaction
- earned-point reversal on returns
- redeemed-point restoration on returns
- sale-level loyalty audit record
- durable sync payloads

### Credit sales

Pay Later sales do not earn loyalty points in the local-only milestone. This is intentional: unpaid customer credit must not create spend rewards that can be redeemed before settlement.

Awarding loyalty across later partial credit collections requires synchronized allocation to the original credit sales and is left to the authenticated settlement integration rather than approximated locally.

## Promotions

Implemented:
- percentage or fixed-amount offers
- basket minimum
- product-specific or all-product eligibility
- start/end timestamps
- active/inactive control
- one deterministic best offer per bill
- no silent stacking
- per-line discount allocation
- discount source/reference on sale lines
- promotion redemption record linked to sale/customer
- owner UI under More → Loyalty & Offers
- cashier Apply offer action

Changing cart quantities invalidates an already applied automatic offer so eligibility is recalculated deliberately.

## Discount auditability

Each discounted sale line carries:
- discount amount
- source: manual / promotion / loyalty
- source reference where applicable

Manual discounts continue to use the existing authorization threshold.

## Returns

When a sale with loyalty is returned:
- points earned on the returned value are reversed proportionally
- points redeemed on the returned value are restored proportionally
- full return restores the customer's pre-sale point position, subject to other unrelated loyalty activity

Corrections are append-only ledger entries; old loyalty entries are never edited.

## Tax safety

Loyalty redemption is currently enabled only when all cart items use tax-inclusive pricing. This keeps configured point value equal to the visible bill reduction in the local implementation.

Promotion discounts remain pre-invoice discounts and continue through the deterministic tax calculator.

Production GST treatment, credit-note requirements and accounting presentation still require current regulatory validation before release.

## External / future boundary

Not claimed in V2.3:
- SMS/WhatsApp loyalty campaigns
- server-synchronized loyalty on Pay Later collections
- tiered membership
- coupon-code distribution
- personalized AI pricing
- regulatory certification of promotional tax treatment

Core billing continues when loyalty/promotions are disabled or unavailable.
