BEGIN;

CREATE TABLE employee_profile (
  user_id uuid PRIMARY KEY REFERENCES app_user(id),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  employee_code text,
  joined_at date,
  active boolean NOT NULL DEFAULT true
);

ALTER TABLE employee_profile ENABLE ROW LEVEL SECURITY;

CREATE POLICY employee_profile_tenant_isolation ON employee_profile
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE TABLE shift (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  employee_user_id uuid NOT NULL REFERENCES app_user(id),
  opened_at timestamptz NOT NULL,
  opening_cash_minor bigint NOT NULL CHECK (opening_cash_minor >= 0),
  closed_at timestamptz,
  expected_closing_cash_minor bigint
    CHECK (expected_closing_cash_minor IS NULL OR expected_closing_cash_minor >= 0),
  actual_closing_cash_minor bigint
    CHECK (actual_closing_cash_minor IS NULL OR actual_closing_cash_minor >= 0),
  variance_minor bigint,
  status text NOT NULL CHECK (status IN ('open', 'closed')),
  closed_by_user_id uuid REFERENCES app_user(id),
  approval_id uuid,
  CHECK (
    (status = 'open' AND closed_at IS NULL)
    OR
    (
      status = 'closed'
      AND closed_at IS NOT NULL
      AND expected_closing_cash_minor IS NOT NULL
      AND actual_closing_cash_minor IS NOT NULL
      AND variance_minor IS NOT NULL
    )
  )
);

CREATE UNIQUE INDEX shift_one_open_terminal_idx
  ON shift (terminal_id)
  WHERE status = 'open';

CREATE TABLE cash_movement (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  shift_id uuid NOT NULL REFERENCES shift(id),
  movement_type text NOT NULL CHECK (movement_type IN ('deposit', 'withdrawal')),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  reason text NOT NULL CHECK (NULLIF(btrim(reason), '') IS NOT NULL),
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE expense (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  shift_id uuid REFERENCES shift(id),
  category text NOT NULL CHECK (NULLIF(btrim(category), '') IS NOT NULL),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  payment_method text NOT NULL
    CHECK (payment_method IN ('cash', 'upi', 'card', 'bank')),
  note text,
  attachment_reference text,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE approval_request (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  action_type text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  requested_by_user_id uuid NOT NULL REFERENCES app_user(id),
  requested_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
  resolved_by_user_id uuid REFERENCES app_user(id),
  resolved_at timestamptz,
  reason text,
  CHECK (
    (status = 'pending' AND resolved_at IS NULL)
    OR
    (status <> 'pending' AND resolved_at IS NOT NULL AND resolved_by_user_id IS NOT NULL)
  )
);

ALTER TABLE sale ADD COLUMN shift_id uuid REFERENCES shift(id);

ALTER TABLE shift ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movement ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_request ENABLE ROW LEVEL SECURITY;

CREATE POLICY shift_tenant_isolation ON shift
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY cash_movement_tenant_isolation ON cash_movement
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY expense_tenant_isolation ON expense
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY approval_request_tenant_isolation ON approval_request
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

COMMIT;
