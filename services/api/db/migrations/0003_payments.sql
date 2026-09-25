BEGIN;

ALTER TABLE payment
  DROP CONSTRAINT IF EXISTS payment_method_check;

ALTER TABLE payment
  ADD CONSTRAINT payment_method_check
  CHECK (method IN ('cash', 'upi', 'card'));

ALTER TABLE payment
  ADD COLUMN provider text,
  ADD COLUMN provider_reference text,
  ADD COLUMN status text NOT NULL DEFAULT 'captured'
    CHECK (status IN ('pending', 'authorized', 'captured', 'failed', 'cancelled')),
  ADD COLUMN reconciliation_status text NOT NULL DEFAULT 'not_applicable'
    CHECK (
      reconciliation_status IN ('not_applicable', 'pending', 'matched', 'mismatch')
    );

ALTER TABLE payment
  ADD CONSTRAINT payment_external_evidence_check
  CHECK (
    method = 'cash'
    OR status <> 'captured'
    OR (provider IS NOT NULL AND provider_reference IS NOT NULL)
  );

CREATE UNIQUE INDEX payment_provider_reference_unique
  ON payment (provider, provider_reference)
  WHERE provider IS NOT NULL AND provider_reference IS NOT NULL;

CREATE TABLE payment_event (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  payment_id uuid NOT NULL REFERENCES payment(id),
  event_type text NOT NULL,
  payment_status text NOT NULL
    CHECK (
      payment_status IN ('pending', 'authorized', 'captured', 'failed', 'cancelled')
    ),
  provider_reference text,
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  occurred_at timestamptz NOT NULL,
  request_id text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX payment_event_payment_time_idx
  ON payment_event (payment_id, occurred_at);

ALTER TABLE payment_event ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_event_tenant_isolation ON payment_event
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
