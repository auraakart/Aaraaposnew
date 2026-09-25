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
