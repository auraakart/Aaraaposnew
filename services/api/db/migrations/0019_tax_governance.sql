BEGIN;

CREATE TABLE tax_rule_version (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  rule_key text NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  classification_type text NOT NULL
    CHECK (classification_type IN ('hsn', 'sac', 'other')),
  classification_code text NOT NULL,
  rate_bps integer NOT NULL CHECK (rate_bps BETWEEN 0 AND 10000),
  price_mode text NOT NULL
    CHECK (price_mode IN ('inclusive', 'exclusive')),
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  status text NOT NULL
    CHECK (status IN ('active', 'retired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to > effective_from),
  UNIQUE (business_id, rule_key, version)
);

CREATE INDEX tax_rule_effective_idx
  ON tax_rule_version (
    business_id,
    rule_key,
    status,
    effective_from DESC
  );

ALTER TABLE product
  ADD COLUMN tax_rule_version_id uuid REFERENCES tax_rule_version(id),
  ADD COLUMN tax_classification_type text
    CHECK (
      tax_classification_type IS NULL
      OR tax_classification_type IN ('hsn', 'sac', 'other')
    ),
  ADD COLUMN tax_classification_code text;

ALTER TABLE sale_line
  ADD COLUMN tax_rate_bps_snapshot integer
    CHECK (
      tax_rate_bps_snapshot IS NULL
      OR tax_rate_bps_snapshot BETWEEN 0 AND 10000
    ),
  ADD COLUMN tax_price_mode_snapshot text
    CHECK (
      tax_price_mode_snapshot IS NULL
      OR tax_price_mode_snapshot IN ('inclusive', 'exclusive')
    ),
  ADD COLUMN tax_classification_type_snapshot text
    CHECK (
      tax_classification_type_snapshot IS NULL
      OR tax_classification_type_snapshot IN ('hsn', 'sac', 'other')
    ),
  ADD COLUMN tax_classification_code_snapshot text,
  ADD COLUMN tax_rule_version_id_snapshot uuid;

ALTER TABLE tax_rule_version ENABLE ROW LEVEL SECURITY;

CREATE POLICY tax_rule_version_tenant_isolation ON tax_rule_version
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
