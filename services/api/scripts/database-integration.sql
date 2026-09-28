\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_relations text;
BEGIN
  SELECT string_agg(required_name, ', ' ORDER BY required_name)
  INTO missing_relations
  FROM unnest(ARRAY[
    'organization',
    'business',
    'store',
    'terminal',
    'app_user',
    'user_role_assignment',
    'audit_event',
    'product',
    'sale',
    'sale_line',
    'payment',
    'stock_movement',
    'customer',
    'supplier',
    'shift',
    'tax_rule_version',
    'recovery_checkpoint',
    'approval_consumption'
  ]) AS required(required_name)
  WHERE to_regclass('public.' || required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Required migrated relations are missing: %',
      missing_relations;
  END IF;
END
$$;

DO $$
DECLARE
  without_rls text;
  without_policy text;
BEGIN
  SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
  INTO without_rls
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND EXISTS (
      SELECT 1
      FROM pg_attribute a
      WHERE a.attrelid = c.oid
        AND a.attname = 'organization_id'
        AND a.attnum > 0
        AND NOT a.attisdropped
    )
    AND NOT c.relrowsecurity;

  IF without_rls IS NOT NULL THEN
    RAISE EXCEPTION
      'Tenant tables with organization_id but RLS disabled: %',
      without_rls;
  END IF;

  SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
  INTO without_policy
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND EXISTS (
      SELECT 1
      FROM pg_attribute a
      WHERE a.attrelid = c.oid
        AND a.attname = 'organization_id'
        AND a.attnum > 0
        AND NOT a.attisdropped
    )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_policy p
      WHERE p.polrelid = c.oid
    );

  IF without_policy IS NOT NULL THEN
    RAISE EXCEPTION
      'Tenant tables with organization_id but no RLS policy: %',
      without_policy;
  END IF;
END
$$;

INSERT INTO organization (id, name)
VALUES
  ('00000000-0000-0000-0000-000000000101', 'RLS Test Org A'),
  ('00000000-0000-0000-0000-000000000102', 'RLS Test Org B');

INSERT INTO business (id, organization_id, name)
VALUES
  (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000101',
    'RLS Test Business A'
  ),
  (
    '00000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000102',
    'RLS Test Business B'
  );

CREATE ROLE aaraapos_rls_test NOLOGIN;
GRANT USAGE ON SCHEMA public TO aaraapos_rls_test;
GRANT SELECT, INSERT ON business TO aaraapos_rls_test;

SET ROLE aaraapos_rls_test;

DO $$
DECLARE
  visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count FROM business;
  IF visible_count <> 0 THEN
    RAISE EXCEPTION
      'Tenant role without app.organization_id unexpectedly saw % business rows',
      visible_count;
  END IF;
END
$$;

SELECT set_config(
  'app.organization_id',
  '00000000-0000-0000-0000-000000000101',
  false
);

DO $$
DECLARE
  visible_count integer;
  visible_id uuid;
BEGIN
  SELECT count(*), min(id)
  INTO visible_count, visible_id
  FROM business;

  IF visible_count <> 1
     OR visible_id <> '00000000-0000-0000-0000-000000000201'::uuid THEN
    RAISE EXCEPTION
      'Tenant RLS read isolation failed: count=%, id=%',
      visible_count,
      visible_id;
  END IF;
END
$$;

DO $$
DECLARE
  blocked boolean := false;
BEGIN
  BEGIN
    INSERT INTO business (id, organization_id, name)
    VALUES (
      '00000000-0000-0000-0000-000000000203',
      '00000000-0000-0000-0000-000000000102',
      'Cross Tenant Write Must Fail'
    );
  EXCEPTION
    WHEN insufficient_privilege THEN
      blocked := true;
  END;

  IF NOT blocked THEN
    RAISE EXCEPTION 'Cross-tenant insert unexpectedly succeeded';
  END IF;
END
$$;

INSERT INTO business (id, organization_id, name)
VALUES (
  '00000000-0000-0000-0000-000000000204',
  '00000000-0000-0000-0000-000000000101',
  'Same Tenant Write'
);

DO $$
DECLARE
  visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count FROM business;
  IF visible_count <> 2 THEN
    RAISE EXCEPTION
      'Same-tenant insert/read failed: expected 2 visible rows, got %',
      visible_count;
  END IF;
END
$$;

RESET ROLE;

SELECT 'PostgreSQL migration/RLS integration smoke test passed.' AS result;
