import test from "node:test";
import assert from "node:assert/strict";
import {
  assertAuthorized,
  AuthorizationError,
  hasPermission,
  type AuthenticatedPrincipal
} from "../src/security.js";

const owner: AuthenticatedPrincipal = {
  userId: "user-owner",
  organizationId: "org-a",
  businessIds: ["business-a"],
  storeIds: ["store-a"],
  role: "owner"
};

test("cashier cannot manage financial configuration", () => {
  assert.equal(hasPermission("cashier", "financial-config:manage"), false);
});

test("owner can manage financial configuration", () => {
  assert.equal(hasPermission("owner", "financial-config:manage"), true);
});

test("cross-business access is rejected", () => {
  assert.throws(
    () => assertAuthorized(owner, {
      organizationId: "org-a",
      businessId: "business-b",
      storeId: "store-a"
    }, "sale:create"),
    AuthorizationError
  );
});

test("cross-store access is rejected", () => {
  assert.throws(
    () => assertAuthorized(owner, {
      organizationId: "org-a",
      businessId: "business-a",
      storeId: "store-b"
    }, "sale:create"),
    AuthorizationError
  );
});

test("authorized scope passes", () => {
  assert.doesNotThrow(() => assertAuthorized(owner, {
    organizationId: "org-a",
    businessId: "business-a",
    storeId: "store-a"
  }, "sale:create"));
});


test("cashier cannot create inter-store transfers", () => {
  assert.equal(hasPermission("cashier", "transfer:create"), false);
  assert.equal(hasPermission("cashier", "transfer:receive"), false);
});

test("stock worker can execute authorized stock transfers", () => {
  assert.equal(hasPermission("stock_worker", "transfer:create"), true);
  assert.equal(hasPermission("stock_worker", "transfer:receive"), true);
});


test("cashier can manage commerce orders but stock worker cannot", () => {
  assert.equal(hasPermission("cashier", "commerce:read"), true);
  assert.equal(hasPermission("cashier", "commerce:manage"), true);
  assert.equal(hasPermission("stock_worker", "commerce:manage"), false);
});


test("audit history is owner/manager only", () => {
  assert.equal(hasPermission("owner", "audit:read"), true);
  assert.equal(hasPermission("manager", "audit:read"), true);
  assert.equal(hasPermission("cashier", "audit:read"), false);
  assert.equal(hasPermission("stock_worker", "audit:read"), false);
});
