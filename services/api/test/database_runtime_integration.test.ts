import test from "node:test";
import assert from "node:assert/strict";

import {
  createPostgresDatabaseFromEnvironment
} from "../src/database.js";

const enabled = process.env.AARAAPOS_DATABASE_INTEGRATION === "1";

test(
  "runtime PostgreSQL role is safe and tenant transaction enforces RLS",
  { skip: !enabled },
  async () => {
    const database = createPostgresDatabaseFromEnvironment(process.env);
    assert.ok(database);

    try {
      assert.deepEqual(await database.readiness(), {
        ready: true,
        code: "READY"
      });

      const scopeA = {
        organizationId: "00000000-0000-0000-0000-000000000101",
        businessId: "00000000-0000-0000-0000-000000000201",
        storeId: "00000000-0000-0000-0000-000000000301"
      };

      const visible = await database.withTenantTransaction(
        scopeA,
        async (transaction) => {
          const result = await transaction.query<{
            id: string;
            organization_id: string;
          }>(
            "SELECT id::text, organization_id::text FROM business ORDER BY id"
          );
          return result.rows;
        }
      );

      assert.ok(visible.length >= 1);
      assert.equal(
        visible.every(
          (row) => row.organization_id === scopeA.organizationId
        ),
        true
      );

      await assert.rejects(
        database.withTenantTransaction(
          scopeA,
          async (transaction) => {
            await transaction.query(
              [
                "INSERT INTO business (id, organization_id, name)",
                "VALUES ($1, $2, $3)"
              ].join(" "),
              [
                "00000000-0000-0000-0000-000000000299",
                "00000000-0000-0000-0000-000000000102",
                "Runtime Cross Tenant Must Fail"
              ]
            );
          }
        )
      );

      await database.withTenantTransaction(
        scopeA,
        async (transaction) => {
          await transaction.query(
            [
              "INSERT INTO business (id, organization_id, name)",
              "VALUES ($1, $2, $3)"
            ].join(" "),
            [
              "00000000-0000-0000-0000-000000000298",
              scopeA.organizationId,
              "Runtime Same Tenant"
            ]
          );
        }
      );

      const inserted = await database.withTenantTransaction(
        scopeA,
        async (transaction) => {
          const result = await transaction.query<{ count: string }>(
            "SELECT count(*)::text AS count FROM business WHERE id = $1",
            ["00000000-0000-0000-0000-000000000298"]
          );
          return Number(result.rows[0]?.count ?? "0");
        }
      );
      assert.equal(inserted, 1);
    } finally {
      await database.close();
    }
  }
);
