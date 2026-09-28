# V2.18 — PostgreSQL Migration & RLS Integration Gate

## Purpose

V2.18 closes the database-integration quality gap from the V0 testing/CI strategy.

Before V2.18, migrations were checked statically for ordering, transaction wrappers and destructive SQL policy, but CI did not prove that the full migration chain actually applies to PostgreSQL.

V2.18 adds a real PostgreSQL 16 integration gate.

## CI database service

Pull-request/develop CI starts an ephemeral:

`postgres:16-alpine`

database with a dedicated disposable CI database.

No production credentials or hosting are involved.

## Migration execution

CI applies every file in:

`services/api/db/migrations/*.sql`

in filename order with:

`psql -v ON_ERROR_STOP=1`

Any SQL error, missing dependency, invalid view/policy syntax, incompatible constraint, or migration-order defect fails the gate.

## Schema smoke test

After migration, the integration script asserts that representative core relations exist across the completed milestones, including:

- organization/business/store/terminal/user
- audit
- product/sale/payment
- stock
- customer
- supplier
- operations
- tax governance
- recovery
- approval governance

This is a structural smoke test, not an exhaustive schema contract.

## Automatic RLS coverage rule

The integration gate inspects the PostgreSQL catalog.

Every ordinary public table containing an `organization_id` column must:

1. have row-level security enabled;
2. have at least one RLS policy.

This rule automatically covers future tenant tables without requiring a manually maintained table allow-list.

A new tenant table that forgets RLS therefore fails CI.

## Behavioral tenant-isolation test

Catalog configuration alone is insufficient, so V2.18 also tests behavior using a non-superuser PostgreSQL role.

The test creates two organizations/businesses and verifies:

- with no `app.organization_id`, the tenant role sees zero business rows;
- with Organization A selected, it sees only Organization A;
- an Organization B insert while scoped to Organization A is blocked by RLS;
- a same-tenant Organization A insert succeeds and is visible.

The test uses a non-superuser role so PostgreSQL superuser RLS bypass cannot produce a false pass.

## Relationship to application authorization

RLS is defense in depth.

The application still must:
- authenticate the principal;
- derive organization/business/store scope server-side;
- enforce RBAC/approval rules;
- set database tenant context from trusted server authorization.

Client-supplied tenant IDs are not trusted merely because RLS exists.

## Definition of done

V2.18 requires the exact PR head to pass:

- API reproducible install/security/policy/typecheck/tests
- Flutter locked restore/analyze/tests/APK compile
- foundation baseline
- full PostgreSQL migration chain
- schema smoke assertions
- catalog RLS coverage
- non-superuser cross-tenant read/write isolation

## Not claimed

V2.18 does not provide:
- production PostgreSQL hosting
- production connection pooling
- schema migration orchestration during deployment
- zero-downtime migration certification
- production backup/restore
- production credentials/secrets
- load/performance testing
- multi-region database design
