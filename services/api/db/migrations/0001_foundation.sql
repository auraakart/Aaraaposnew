BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE organization (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE business (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  name text NOT NULL,
  gstin text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE store (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  name text NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, name)
);

CREATE TABLE terminal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  display_name text NOT NULL,
  mobile_e164 text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'disabled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_role_assignment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  user_id uuid NOT NULL REFERENCES app_user(id),
  role text NOT NULL
    CHECK (role IN ('owner', 'manager', 'cashier', 'stock_worker')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, store_id, user_id, role)
);

CREATE TABLE audit_event (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  action text NOT NULL,
  affected_entity_type text NOT NULL,
  affected_entity_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  reason text,
  approval_id uuid,
  request_id text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX audit_event_scope_time_idx
  ON audit_event (organization_id, business_id, store_id, occurred_at DESC);

ALTER TABLE business ENABLE ROW LEVEL SECURITY;
ALTER TABLE store ENABLE ROW LEVEL SECURITY;
ALTER TABLE terminal ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_role_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_event ENABLE ROW LEVEL SECURITY;

CREATE POLICY business_tenant_isolation ON business
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE POLICY store_tenant_isolation ON store
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE POLICY terminal_tenant_isolation ON terminal
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE POLICY app_user_tenant_isolation ON app_user
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE POLICY user_role_tenant_isolation ON user_role_assignment
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE POLICY audit_event_tenant_isolation ON audit_event
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

COMMIT;
