BEGIN;

CREATE TABLE ai_insight (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  insight_type text NOT NULL,
  classification text NOT NULL
    CHECK (
      classification IN ('fact', 'calculation', 'prediction', 'recommendation')
    ),
  title text NOT NULL CHECK (NULLIF(btrim(title), '') IS NOT NULL),
  message text NOT NULL CHECK (NULLIF(btrim(message), '') IS NOT NULL),
  evidence jsonb NOT NULL CHECK (jsonb_array_length(evidence) > 0),
  generated_by text NOT NULL
    CHECK (generated_by IN ('deterministic', 'external_ai')),
  provider text,
  model text,
  generated_at timestamptz NOT NULL,
  expires_at timestamptz,
  acknowledged_at timestamptz
);

CREATE INDEX ai_insight_business_time_idx
  ON ai_insight (business_id, generated_at DESC);

ALTER TABLE ai_insight ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_insight_tenant_isolation ON ai_insight
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
