BEGIN;

CREATE TABLE accounting_export_batch (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  format text NOT NULL CHECK (format IN ('csv', 'json')),
  row_count integer NOT NULL CHECK (row_count >= 0),
  content_hash text NOT NULL,
  status text NOT NULL
    CHECK (status IN ('generated', 'delivered', 'failed')),
  provider_id uuid REFERENCES integration_provider(id),
  provider_reference text,
  created_by_user_id uuid NOT NULL REFERENCES app_user(id),
  created_at timestamptz NOT NULL,
  delivered_at timestamptz,
  error_code text,
  CHECK (period_start < period_end),
  CHECK (
    (status = 'generated' AND delivered_at IS NULL)
    OR
    (status = 'delivered' AND delivered_at IS NOT NULL)
    OR
    (status = 'failed')
  ),
  CHECK (
    provider_id IS NULL
    OR status IN ('delivered', 'failed')
  )
);

CREATE TABLE accounting_export_source (
  accounting_export_batch_id uuid NOT NULL
    REFERENCES accounting_export_batch(id) ON DELETE CASCADE,
  source_kind text NOT NULL
    CHECK (
      source_kind IN (
        'sales',
        'returns',
        'purchases',
        'expenses',
        'customer_credit',
        'supplier_ledger'
      )
    ),
  source_id uuid NOT NULL,
  PRIMARY KEY (accounting_export_batch_id, source_kind, source_id)
);

CREATE INDEX accounting_export_business_time_idx
  ON accounting_export_batch (business_id, created_at DESC);

ALTER TABLE accounting_export_batch ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounting_export_source ENABLE ROW LEVEL SECURITY;

CREATE POLICY accounting_export_batch_tenant_isolation
  ON accounting_export_batch
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY accounting_export_source_tenant_isolation
  ON accounting_export_source
  USING (
    EXISTS (
      SELECT 1
      FROM accounting_export_batch batch
      WHERE batch.id = accounting_export_batch_id
        AND batch.organization_id =
          NULLIF(current_setting('app.organization_id', true), '')::uuid
    )
  );

COMMIT;
