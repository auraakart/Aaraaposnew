export type CommerceChannel = "whatsapp" | "web" | "phone" | "manual";
export type CommerceOrderStatus =
  | "received"
  | "confirmed"
  | "ready"
  | "completed"
  | "cancelled";

export interface CommerceOrderLine {
  productId: string;
  quantityMilli: number;
  quotedUnitPriceMinor?: number;
}

export interface CommerceOrder {
  id: string;
  organizationId: string;
  businessId: string;
  storeId: string;
  channel: CommerceChannel;
  status: CommerceOrderStatus;
  customerId?: string;
  externalConversationRef?: string;
  lines: readonly CommerceOrderLine[];
  saleId?: string;
}

function assertPositiveMilli(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Order quantity must be a positive integer milli-unit");
  }
}

export function validateCommerceOrder(order: CommerceOrder): void {
  if (
    !order.id.trim() ||
    !order.organizationId.trim() ||
    !order.businessId.trim() ||
    !order.storeId.trim()
  ) {
    throw new Error("Commerce order scope is required");
  }
  if (order.lines.length === 0) {
    throw new Error("Commerce order requires at least one item");
  }
  const products = new Set<string>();
  for (const line of order.lines) {
    if (!line.productId.trim()) throw new Error("Product ID is required");
    assertPositiveMilli(line.quantityMilli);
    if (
      line.quotedUnitPriceMinor !== undefined &&
      (!Number.isSafeInteger(line.quotedUnitPriceMinor) ||
        line.quotedUnitPriceMinor < 0)
    ) {
      throw new Error("Quoted price must be non-negative integer paise");
    }
    if (products.has(line.productId)) {
      throw new Error("Duplicate product lines are not allowed");
    }
    products.add(line.productId);
  }

  if (order.status === "completed" && !order.saleId) {
    throw new Error("Completed commerce order must link to a sale");
  }
  if (order.status !== "completed" && order.saleId) {
    throw new Error("Only a completed commerce order may link to a sale");
  }
}

export function nextCommerceOrderStatus(
  current: CommerceOrderStatus,
  action: "confirm" | "ready" | "complete" | "cancel"
): CommerceOrderStatus {
  if (current === "received" && action === "confirm") return "confirmed";
  if (current === "confirmed" && action === "ready") return "ready";
  if (
    (current === "confirmed" || current === "ready") &&
    action === "complete"
  ) {
    return "completed";
  }
  if (
    (current === "received" ||
      current === "confirmed" ||
      current === "ready") &&
    action === "cancel"
  ) {
    return "cancelled";
  }
  throw new Error(`Invalid commerce transition: ${current} -> ${action}`);
}

export function commerceOrderToSaleIntent(order: CommerceOrder): {
  orderId: string;
  customerId?: string;
  lines: readonly { productId: string; quantityMilli: number }[];
} {
  validateCommerceOrder(order);
  if (order.status === "cancelled" || order.status === "completed") {
    throw new Error("Commerce order cannot be converted to a sale");
  }
  return {
    orderId: order.id,
    ...(order.customerId === undefined ? {} : { customerId: order.customerId }),
    lines: order.lines.map((line) => ({
      productId: line.productId,
      quantityMilli: line.quantityMilli
    }))
  };
}

export type CommunicationConsent = "unknown" | "opted_in" | "opted_out";

export function canSendProactiveCommerceMessage(input: {
  channel: CommerceChannel;
  consent: CommunicationConsent;
  providerConfigured: boolean;
}): boolean {
  if (input.channel !== "whatsapp") return false;
  return input.providerConfigured && input.consent === "opted_in";
}

export function inboundCommerceEventKey(input: {
  provider: string;
  providerEventId: string;
}): string {
  if (!input.provider.trim() || !input.providerEventId.trim()) {
    throw new Error("Provider and event ID are required");
  }
  return `commerce-event:${input.provider}:${input.providerEventId}`;
}
