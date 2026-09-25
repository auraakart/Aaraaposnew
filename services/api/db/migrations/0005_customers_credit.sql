BEGIN;

CREATE TABLE customer (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  name text NOT NULL,
  mobile_e164 text,
  communication_consent text NOT NULL DEFAULT 'unknown'
    CHECK (communication_consent IN ('unknown', 'opted_in', 'opted_out')),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE INDEX customer_business_name_idx
  ON customer (business_id, lower(name));

CREATE INDEX customer_business_mobile_idx
  ON customer (business_id, mobile_e164)
  WHERE mobile_e164 IS NOT NULL;

ALTER TABLE customer ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_tenant_isolation ON customer
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

ALTER TABLE sale
  ADD COLUMN customer_id uuid REFERENCES customer(id);

ALTER TABLE payment
  DROP CONSTRAINT IF EXISTS payment_method_check;

ALTER TABLE payment
  ADD CONSTRAINT payment_method_check
  CHECK (method IN ('cash', 'upi', 'card', 'customer_credit'));

ALTER TABLE payment
  DROP CONSTRAINT IF EXISTS payment_external_evidence_check;

ALTER TABLE payment
  ADD CONSTRAINT payment_external_evidence_check
  CHECK (
    method IN ('cash', 'customer_credit')
    OR status <> 'captured'
    OR (provider IS NOT NULL AND provider_reference IS NOT NULL)
  );

CREATE TABLE customer_credit_entry (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  customer_id uuid NOT NULL REFERENCES customer(id),
  entry_type text NOT NULL
    CHECK (
      entry_type IN (
        'charge',
        'payment',
        'correction_increase',
        'correction_decrease'
      )
    ),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  sale_id uuid REFERENCES sale(id),
  collection_method text
    CHECK (
      collection_method IS NULL
      OR collection_method IN ('cash', 'upi', 'card')
    ),
  due_date date,
  note text,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (organization_id, idempotency_key),
  CHECK (entry_type <> 'charge' OR sale_id IS NOT NULL),
  CHECK (entry_type <> 'payment' OR collection_method IS NOT NULL)
);

CREATE INDEX customer_credit_entry_customer_time_idx
  ON customer_credit_entry (customer_id, occurred_at, id);

ALTER TABLE customer_credit_entry ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_credit_entry_tenant_isolation
  ON customer_credit_entry
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE VIEW customer_credit_balance
WITH (security_invoker = true) AS
SELECT
  organization_id,
  business_id,
  customer_id,
  SUM(
    CASE
      WHEN entry_type IN ('charge', 'correction_increase')
        THEN amount_minor
      ELSE -amount_minor
    END
  ) AS balance_minor
FROM customer_credit_entry
GROUP BY organization_id, business_id, customer_id;

COMMIT;
