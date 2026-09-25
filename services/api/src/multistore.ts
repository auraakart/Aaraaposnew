import {
  AuthorizationError,
  type AuthenticatedPrincipal,
  type Permission,
  assertAuthorized
} from "./security.js";

export type StoreTransferStatus =
  | "draft"
  | "dispatched"
  | "received"
  | "cancelled";

export interface StoreIdentity {
  id: string;
  organizationId: string;
  businessId: string;
  name: string;
  active: boolean;
}

export interface StoreTransferLine {
  productId: string;
  quantityMilli: number;
}

export interface StoreTransfer {
  id: string;
  organizationId: string;
  businessId: string;
  sourceStoreId: string;
  destinationStoreId: string;
  status: StoreTransferStatus;
  lines: readonly StoreTransferLine[];
}

function assertPositiveMilli(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Transfer quantity must be a positive integer milli-unit");
  }
}

export function validateStoreTransfer(transfer: StoreTransfer): void {
  if (transfer.sourceStoreId === transfer.destinationStoreId) {
    throw new Error("Source and destination stores must be different");
  }
  if (transfer.lines.length === 0) {
    throw new Error("Transfer requires at least one item");
  }

  const products = new Set<string>();
  for (const line of transfer.lines) {
    assertPositiveMilli(line.quantityMilli);
    if (products.has(line.productId)) {
      throw new Error("Duplicate product lines are not allowed");
    }
    products.add(line.productId);
  }
}

export function assertTransferAuthorized(
  principal: AuthenticatedPrincipal,
  transfer: StoreTransfer,
  permission: Permission = "inventory:adjust"
): void {
  validateStoreTransfer(transfer);

  assertAuthorized(
    principal,
    {
      organizationId: transfer.organizationId,
      businessId: transfer.businessId,
      storeId: transfer.sourceStoreId
    },
    permission
  );

  assertAuthorized(
    principal,
    {
      organizationId: transfer.organizationId,
      businessId: transfer.businessId,
      storeId: transfer.destinationStoreId
    },
    permission
  );
}

export function assertSameBusinessStores(
  source: StoreIdentity,
  destination: StoreIdentity
): void {
  if (
    source.organizationId !== destination.organizationId ||
    source.businessId !== destination.businessId
  ) {
    throw new AuthorizationError();
  }
  if (!source.active || !destination.active) {
    throw new Error("Transfers require active stores");
  }
  if (source.id === destination.id) {
    throw new Error("Source and destination stores must be different");
  }
}

export function nextTransferStatus(
  current: StoreTransferStatus,
  action: "dispatch" | "receive" | "cancel"
): StoreTransferStatus {
  if (action === "dispatch" && current === "draft") return "dispatched";
  if (action === "receive" && current === "dispatched") return "received";
  if (action === "cancel" && current === "draft") return "cancelled";
  throw new Error(`Invalid transfer transition: ${current} -> ${action}`);
}

export interface StoreMetric {
  storeId: string;
  salesMinor: number;
  billCount: number;
  expensesMinor: number;
  refundsMinor: number;
}

export interface MultiStoreSummary {
  salesMinor: number;
  billCount: number;
  expensesMinor: number;
  refundsMinor: number;
  stores: readonly StoreMetric[];
}

export function aggregateStoreMetrics(
  metrics: readonly StoreMetric[]
): MultiStoreSummary {
  const ids = new Set<string>();
  let salesMinor = 0;
  let billCount = 0;
  let expensesMinor = 0;
  let refundsMinor = 0;

  for (const metric of metrics) {
    if (ids.has(metric.storeId)) {
      throw new Error("Duplicate store metrics are not allowed");
    }
    ids.add(metric.storeId);

    for (const [field, value] of Object.entries({
      salesMinor: metric.salesMinor,
      billCount: metric.billCount,
      expensesMinor: metric.expensesMinor,
      refundsMinor: metric.refundsMinor
    })) {
      if (!Number.isSafeInteger(value) || value < 0) {
        throw new Error(`${field} must be a non-negative integer`);
      }
    }

    salesMinor += metric.salesMinor;
    billCount += metric.billCount;
    expensesMinor += metric.expensesMinor;
    refundsMinor += metric.refundsMinor;
  }

  return {
    salesMinor,
    billCount,
    expensesMinor,
    refundsMinor,
    stores: metrics
  };
}


export interface TransferStockEvent {
  storeId: string;
  productId: string;
  movementType: "transfer_out" | "transfer_in";
  quantityDeltaMilli: number;
  sourceEntityType: "store_transfer";
  sourceEntityId: string;
}

export function transferStockEvents(
  transfer: StoreTransfer
): readonly TransferStockEvent[] {
  validateStoreTransfer(transfer);
  if (transfer.status !== "dispatched" && transfer.status !== "received") {
    throw new Error("Stock events require a dispatched or received transfer");
  }

  const events: TransferStockEvent[] = [];
  for (const line of transfer.lines) {
    events.push({
      storeId: transfer.sourceStoreId,
      productId: line.productId,
      movementType: "transfer_out",
      quantityDeltaMilli: -line.quantityMilli,
      sourceEntityType: "store_transfer",
      sourceEntityId: transfer.id
    });
    if (transfer.status === "received") {
      events.push({
        storeId: transfer.destinationStoreId,
        productId: line.productId,
        movementType: "transfer_in",
        quantityDeltaMilli: line.quantityMilli,
        sourceEntityType: "store_transfer",
        sourceEntityId: transfer.id
      });
    }
  }
  return events;
}
