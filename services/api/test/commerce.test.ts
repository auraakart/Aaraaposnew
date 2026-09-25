import test from "node:test";
import assert from "node:assert/strict";
import {
  canSendProactiveCommerceMessage,
  commerceOrderToSaleIntent,
  inboundCommerceEventKey,
  nextCommerceOrderStatus,
  type CommerceOrder
} from "../src/commerce.js";

const order: CommerceOrder = {
  id: "order-1",
  organizationId: "org-1",
  businessId: "business-1",
  storeId: "store-1",
  channel: "whatsapp",
  status: "received",
  customerId: "customer-1",
  externalConversationRef: "conversation-1",
  lines: [
    { productId: "milk", quantityMilli: 2000, quotedUnitPriceMinor: 6000 }
  ]
};

test("commerce lifecycle cannot skip from received to ready", () => {
  assert.equal(nextCommerceOrderStatus("received", "confirm"), "confirmed");
  assert.equal(nextCommerceOrderStatus("confirmed", "ready"), "ready");
  assert.equal(nextCommerceOrderStatus("ready", "complete"), "completed");
  assert.throws(() => nextCommerceOrderStatus("received", "ready"));
});

test("commerce conversion produces product quantities, not financial records", () => {
  assert.deepEqual(commerceOrderToSaleIntent(order), {
    orderId: "order-1",
    customerId: "customer-1",
    lines: [{ productId: "milk", quantityMilli: 2000 }]
  });
});

test("proactive WhatsApp requires both provider and explicit opt-in", () => {
  assert.equal(
    canSendProactiveCommerceMessage({
      channel: "whatsapp",
      consent: "opted_in",
      providerConfigured: true
    }),
    true
  );
  assert.equal(
    canSendProactiveCommerceMessage({
      channel: "whatsapp",
      consent: "unknown",
      providerConfigured: true
    }),
    false
  );
  assert.equal(
    canSendProactiveCommerceMessage({
      channel: "whatsapp",
      consent: "opted_in",
      providerConfigured: false
    }),
    false
  );
});

test("provider event IDs produce stable inbound dedupe keys", () => {
  assert.equal(
    inboundCommerceEventKey({
      provider: "example-whatsapp",
      providerEventId: "evt-1"
    }),
    "commerce-event:example-whatsapp:evt-1"
  );
});
