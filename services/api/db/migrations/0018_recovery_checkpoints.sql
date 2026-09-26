BEGIN;

CREATE TABLE recovery_checkpoint (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  scope text NOT NULL CHECK (scope IN ('business', 'store')),
  schema_version integer NOT NULL CHECK (schema_version > 0),
  created_at timestamptz NOT NULL,
  content_hash text NOT NULL
    CHECK (content_hash ~ '^[0-9a-f]{64}$'),
  encrypted boolean NOT NULL CHECK (encrypted = true),
  storage_reference text NOT NULL,
  status text NOT NULL
    CHECK (status IN ('available', 'verified', 'invalid', 'expired')),
  record_counts jsonb NOT NULL DEFAULT '{}'::jsonb,
  verified_at timestamptz,
  expires_at timestamptz,
  CHECK (
    (scope = 'store' AND store_id IS NOT NULL)
    OR
    (scope = 'business' AND store_id IS NULL)
  )
);

CREATE INDEX recovery_checkpoint_scope_time_idx
  ON recovery_checkpoint (
    organization_id,
    business_id,
    store_id,
    created_at DESC
  );

CREATE TABLE recovery_rehearsal (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  checkpoint_id uuid NOT NULL REFERENCES recovery_checkpoint(id),
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  mode text NOT NULL CHECK (mode IN ('dry_run')),
  status text NOT NULL CHECK (status IN ('passed', 'blocked', 'failed')),
  blockers jsonb NOT NULL DEFAULT '[]'::jsonb,
  warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
  occurred_at timestamptz NOT NULL,
  request_id text NOT NULL
);

CREATE INDEX recovery_rehearsal_scope_time_idx
  ON recovery_rehearsal (
    organization_id,
    business_id,
    store_id,
    occurred_at DESC
  );

ALTER TABLE recovery_checkpoint ENABLE ROW LEVEL SECURITY;
ALTER TABLE recovery_rehearsal ENABLE ROW LEVEL SECURITY;

CREATE POLICY recovery_checkpoint_tenant_isolation ON recovery_checkpoint
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY recovery_rehearsal_tenant_isolation ON recovery_rehearsal
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
