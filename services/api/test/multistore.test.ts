import test from "node:test";
import assert from "node:assert/strict";
import {
  aggregateStoreMetrics,
  assertSameBusinessStores,
  assertTransferAuthorized,
  nextTransferStatus,
  type StoreTransfer
} from "../src/multistore.js";
import { AuthorizationError, type AuthenticatedPrincipal } from "../src/security.js";

const transfer: StoreTransfer = {
  id: "transfer-1",
  organizationId: "org-1",
  businessId: "business-1",
  sourceStoreId: "store-a",
  destinationStoreId: "store-b",
  status: "draft",
  lines: [{ productId: "milk", quantityMilli: 5000 }]
};

test("transfer requires access to both stores", () => {
  const owner: AuthenticatedPrincipal = {
    userId: "owner-1",
    organizationId: "org-1",
    businessIds: ["business-1"],
    storeIds: ["store-a", "store-b"],
    role: "owner"
  };
  assert.doesNotThrow(() => assertTransferAuthorized(owner, transfer));

  const sourceOnly: AuthenticatedPrincipal = {
    ...owner,
    storeIds: ["store-a"]
  };
  assert.throws(
    () => assertTransferAuthorized(sourceOnly, transfer),
    AuthorizationError
  );
});

test("stores in different businesses cannot transfer", () => {
  assert.throws(
    () =>
      assertSameBusinessStores(
        {
          id: "store-a",
          organizationId: "org-1",
          businessId: "business-1",
          name: "A",
          active: true
        },
        {
          id: "store-b",
          organizationId: "org-1",
          businessId: "business-2",
          name: "B",
          active: true
        }
      ),
    AuthorizationError
  );
});

test("transfer status is one-way and auditable", () => {
  assert.equal(nextTransferStatus("draft", "dispatch"), "dispatched");
  assert.equal(nextTransferStatus("dispatched", "receive"), "received");
  assert.throws(() => nextTransferStatus("received", "cancel"));
});

test("store metrics aggregate without losing store detail", () => {
  assert.deepEqual(
    aggregateStoreMetrics([
      {
        storeId: "store-a",
        salesMinor: 100000,
        billCount: 10,
        expensesMinor: 10000,
        refundsMinor: 5000
      },
      {
        storeId: "store-b",
        salesMinor: 50000,
        billCount: 5,
        expensesMinor: 4000,
        refundsMinor: 0
      }
    ]),
    {
      salesMinor: 150000,
      billCount: 15,
      expensesMinor: 14000,
      refundsMinor: 5000,
      stores: [
        {
          storeId: "store-a",
          salesMinor: 100000,
          billCount: 10,
          expensesMinor: 10000,
          refundsMinor: 5000
        },
        {
          storeId: "store-b",
          salesMinor: 50000,
          billCount: 5,
          expensesMinor: 4000,
          refundsMinor: 0
        }
      ]
    }
  );
});
