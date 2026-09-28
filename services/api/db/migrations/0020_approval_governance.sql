BEGIN;

ALTER TABLE approval_request
  ADD COLUMN action_fingerprint text,
  ADD COLUMN requested_amount_minor bigint
    CHECK (
      requested_amount_minor IS NULL
      OR requested_amount_minor >= 0
    ),
  ADD COLUMN expires_at timestamptz;

CREATE INDEX approval_request_pending_scope_idx
  ON approval_request (
    organization_id,
    business_id,
    store_id,
    status,
    requested_at DESC
  );

CREATE INDEX approval_request_fingerprint_idx
  ON approval_request (
    organization_id,
    business_id,
    action_type,
    entity_type,
    entity_id,
    action_fingerprint
  )
  WHERE action_fingerprint IS NOT NULL;

CREATE TABLE approval_consumption (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  approval_request_id uuid NOT NULL UNIQUE REFERENCES approval_request(id),
  consumed_by_user_id uuid NOT NULL REFERENCES app_user(id),
  action_fingerprint text NOT NULL,
  consumed_at timestamptz NOT NULL,
  request_id text NOT NULL
);

CREATE INDEX approval_consumption_scope_time_idx
  ON approval_consumption (
    organization_id,
    business_id,
    store_id,
    consumed_at DESC
  );

ALTER TABLE approval_consumption ENABLE ROW LEVEL SECURITY;

CREATE POLICY approval_consumption_tenant_isolation ON approval_consumption
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
