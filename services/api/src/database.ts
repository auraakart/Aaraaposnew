import {
  Pool,
  type PoolClient,
  type PoolConfig,
  type QueryResult,
  type QueryResultRow
} from "pg";

export interface DatabaseScope {
  organizationId: string;
  businessId: string;
  storeId: string;
}

export interface RuntimeDatabaseConfig {
  connectionString: string;
  max: number;
  connectionTimeoutMillis: number;
  idleTimeoutMillis: number;
  applicationName: string;
}

export interface DatabaseReadiness {
  ready: boolean;
  code:
    | "READY"
    | "DATABASE_UNAVAILABLE"
    | "UNSAFE_DATABASE_ROLE"
    | "SCHEMA_NOT_READY";
}

export interface TenantTransaction {
  query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    values?: readonly unknown[]
  ): Promise<QueryResult<T>>;
}

export class DatabaseConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DatabaseConfigurationError";
  }
}

export class UnsafeDatabaseRoleError extends Error {
  constructor() {
    super(
      "Runtime database role must not be superuser, BYPASSRLS, or own tenant tables."
    );
    this.name = "UnsafeDatabaseRoleError";
  }
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function parseBoundedInteger(
  raw: string | undefined,
  field: string,
  fallback: number,
  minimum: number,
  maximum: number
): number {
  if (raw === undefined || !raw.trim()) return fallback;
  const value = Number(raw);
  if (
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new DatabaseConfigurationError(
      field + " must be an integer between " + minimum + " and " + maximum
    );
  }
  return value;
}

export function parseRuntimeDatabaseConfig(
  env: NodeJS.ProcessEnv
): RuntimeDatabaseConfig | undefined {
  const raw = env.DATABASE_URL?.trim();
  if (!raw) return undefined;

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new DatabaseConfigurationError(
      "DATABASE_URL must be a valid PostgreSQL URL"
    );
  }

  if (
    (url.protocol !== "postgres:" &&
      url.protocol !== "postgresql:") ||
    !url.hostname ||
    !url.pathname ||
    url.pathname === "/"
  ) {
    throw new DatabaseConfigurationError(
      "DATABASE_URL must identify a PostgreSQL database"
    );
  }

  return {
    connectionString: raw,
    max: parseBoundedInteger(
      env.DB_POOL_MAX,
      "DB_POOL_MAX",
      10,
      1,
      50
    ),
    connectionTimeoutMillis: parseBoundedInteger(
      env.DB_CONNECT_TIMEOUT_MS,
      "DB_CONNECT_TIMEOUT_MS",
      5000,
      1000,
      30000
    ),
    idleTimeoutMillis: parseBoundedInteger(
      env.DB_IDLE_TIMEOUT_MS,
      "DB_IDLE_TIMEOUT_MS",
      30000,
      1000,
      300000
    ),
    applicationName: "aaraapos-api"
  };
}

export function assertValidDatabaseScope(scope: DatabaseScope): void {
  for (const [field, value] of Object.entries(scope)) {
    if (!uuidPattern.test(value)) {
      throw new DatabaseConfigurationError(field + " must be a UUID");
    }
  }
}

function poolConfig(config: RuntimeDatabaseConfig): PoolConfig {
  return {
    connectionString: config.connectionString,
    max: config.max,
    connectionTimeoutMillis: config.connectionTimeoutMillis,
    idleTimeoutMillis: config.idleTimeoutMillis,
    application_name: config.applicationName
  };
}

async function assertSafeRuntimeRole(
  client: PoolClient
): Promise<void> {
  const result = await client.query<{
    rolsuper: boolean;
    rolbypassrls: boolean;
    owns_tenant_table: boolean;
  }>(
    [
      "SELECT",
      "  r.rolsuper,",
      "  r.rolbypassrls,",
      "  EXISTS (",
      "    SELECT 1",
      "    FROM pg_class c",
      "    JOIN pg_namespace n ON n.oid = c.relnamespace",
      "    WHERE n.nspname = 'public'",
      "      AND c.relkind = 'r'",
      "      AND c.relowner = r.oid",
      "      AND EXISTS (",
      "        SELECT 1",
      "        FROM pg_attribute a",
      "        WHERE a.attrelid = c.oid",
      "          AND a.attname = 'organization_id'",
      "          AND a.attnum > 0",
      "          AND NOT a.attisdropped",
      "      )",
      "  ) AS owns_tenant_table",
      "FROM pg_roles r",
      "WHERE r.rolname = current_user"
    ].join("\n")
  );

  const role = result.rows[0];
  if (
    role === undefined ||
    role.rolsuper ||
    role.rolbypassrls ||
    role.owns_tenant_table
  ) {
    throw new UnsafeDatabaseRoleError();
  }
}

export class PostgresRuntimeDatabase {
  private readonly pool: Pool;
  private safeRoleVerified = false;

  constructor(config: RuntimeDatabaseConfig) {
    this.pool = new Pool(poolConfig(config));
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async readiness(): Promise<DatabaseReadiness> {
    let client: PoolClient | undefined;
    try {
      client = await this.pool.connect();
      await assertSafeRuntimeRole(client);
      this.safeRoleVerified = true;

      const schema = await client.query<{ organization_table: string | null }>(
        "SELECT to_regclass('public.organization')::text AS organization_table"
      );
      if (schema.rows[0]?.organization_table !== "organization") {
        return { ready: false, code: "SCHEMA_NOT_READY" };
      }

      await client.query("SELECT 1");
      return { ready: true, code: "READY" };
    } catch (error) {
      if (error instanceof UnsafeDatabaseRoleError) {
        return { ready: false, code: "UNSAFE_DATABASE_ROLE" };
      }
      return { ready: false, code: "DATABASE_UNAVAILABLE" };
    } finally {
      client?.release();
    }
  }

  async withTenantTransaction<T>(
    scope: DatabaseScope,
    operation: (transaction: TenantTransaction) => Promise<T>
  ): Promise<T> {
    assertValidDatabaseScope(scope);
    const client = await this.pool.connect();
    let began = false;

    try {
      await client.query("BEGIN");
      began = true;

      if (!this.safeRoleVerified) {
        await assertSafeRuntimeRole(client);
        this.safeRoleVerified = true;
      }

      await client.query(
        [
          "SELECT",
          "  set_config('app.organization_id', $1, true),",
          "  set_config('app.business_id', $2, true),",
          "  set_config('app.store_id', $3, true)"
        ].join("\n"),
        [scope.organizationId, scope.businessId, scope.storeId]
      );

      const transaction: TenantTransaction = {
        query: async <R extends QueryResultRow = QueryResultRow>(
          text: string,
          values: readonly unknown[] = []
        ): Promise<QueryResult<R>> =>
          client.query<R>(text, [...values])
      };

      const result = await operation(transaction);
      await client.query("COMMIT");
      began = false;
      return result;
    } catch (error) {
      if (began) {
        try {
          await client.query("ROLLBACK");
        } catch {
          // Preserve the original transaction error.
        }
      }
      throw error;
    } finally {
      client.release();
    }
  }
}

export function createPostgresDatabaseFromEnvironment(
  env: NodeJS.ProcessEnv = process.env
): PostgresRuntimeDatabase | undefined {
  const config = parseRuntimeDatabaseConfig(env);
  return config === undefined
    ? undefined
    : new PostgresRuntimeDatabase(config);
}
