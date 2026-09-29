import test from "node:test";
import assert from "node:assert/strict";

import {
  assertValidDatabaseScope,
  DatabaseConfigurationError,
  parseRuntimeDatabaseConfig
} from "../src/database.js";

test("database runtime is optional when DATABASE_URL is absent", () => {
  assert.equal(parseRuntimeDatabaseConfig({}), undefined);
});

test("database configuration parses bounded pool settings", () => {
  const config = parseRuntimeDatabaseConfig({
    DATABASE_URL:
      "postgresql://aaraapos_app:secret@db.example.com:5432/aaraapos",
    DB_POOL_MAX: "12",
    DB_CONNECT_TIMEOUT_MS: "7000",
    DB_IDLE_TIMEOUT_MS: "45000"
  });

  assert.deepEqual(config, {
    connectionString:
      "postgresql://aaraapos_app:secret@db.example.com:5432/aaraapos",
    max: 12,
    connectionTimeoutMillis: 7000,
    idleTimeoutMillis: 45000,
    applicationName: "aaraapos-api"
  });
});

test("invalid database URL and pool bounds fail fast", () => {
  assert.throws(
    () =>
      parseRuntimeDatabaseConfig({
        DATABASE_URL: "https://db.example.com/aaraapos"
      }),
    DatabaseConfigurationError
  );

  assert.throws(
    () =>
      parseRuntimeDatabaseConfig({
        DATABASE_URL: "postgresql://db.example.com/aaraapos",
        DB_POOL_MAX: "0"
      }),
    DatabaseConfigurationError
  );

  assert.throws(
    () =>
      parseRuntimeDatabaseConfig({
        DATABASE_URL: "postgresql://db.example.com/aaraapos",
        DB_CONNECT_TIMEOUT_MS: "999999"
      }),
    DatabaseConfigurationError
  );
});

test("tenant scope accepts PostgreSQL canonical UUID syntax", () => {
  assert.doesNotThrow(() =>
    assertValidDatabaseScope({
      organizationId: "00000000-0000-0000-0000-000000000101",
      businessId: "00000000-0000-0000-0000-000000000201",
      storeId: "00000000-0000-0000-0000-000000000301"
    })
  );

  assert.throws(
    () =>
      assertValidDatabaseScope({
        organizationId: "org-1",
        businessId: "00000000-0000-0000-0000-000000000201",
        storeId: "00000000-0000-0000-0000-000000000301"
      }),
    DatabaseConfigurationError
  );
});
