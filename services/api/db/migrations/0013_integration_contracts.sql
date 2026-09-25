BEGIN;

CREATE TABLE sync_ingest_receipt (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  idempotency_key text NOT NULL,
  schema_version integer NOT NULL CHECK (schema_version > 0),
  payload_hash text NOT NULL,
  state text NOT NULL
    CHECK (state IN ('acknowledged', 'conflict', 'rejected')),
  result_code text,
  result_message text,
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, idempotency_key)
);

CREATE INDEX sync_ingest_scope_time_idx
  ON sync_ingest_receipt (
    organization_id,
    business_id,
    store_id,
    received_at DESC
  );

CREATE TABLE integration_provider (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  provider_type text NOT NULL
    CHECK (
      provider_type IN ('payment', 'messaging', 'tax', 'accounting')
    ),
  provider_name text NOT NULL,
  configured boolean NOT NULL DEFAULT false,
  capabilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  config_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, provider_type, provider_name),
  CHECK (
    NOT configured OR config_reference IS NOT NULL
  )
);

CREATE TABLE provider_webhook_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  provider_id uuid NOT NULL REFERENCES integration_provider(id),
  provider_event_id text NOT NULL,
  provider_reference text,
  payload_hash text NOT NULL,
  signature_valid boolean NOT NULL,
  timestamp_valid boolean NOT NULL,
  processing_state text NOT NULL
    CHECK (
      processing_state IN ('accepted', 'duplicate', 'rejected', 'processed')
    ),
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  result_code text,
  UNIQUE (provider_id, provider_event_id)
);

CREATE INDEX provider_webhook_business_time_idx
  ON provider_webhook_event (business_id, received_at DESC);

ALTER TABLE sync_ingest_receipt ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration_provider ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_webhook_event ENABLE ROW LEVEL SECURITY;

CREATE POLICY sync_ingest_tenant_isolation ON sync_ingest_receipt
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY integration_provider_tenant_isolation ON integration_provider
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY provider_webhook_tenant_isolation ON provider_webhook_event
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
