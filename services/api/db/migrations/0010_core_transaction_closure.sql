BEGIN;

CREATE TABLE sale_return (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  sale_id uuid NOT NULL REFERENCES sale(id),
  return_number text NOT NULL,
  reason text NOT NULL CHECK (NULLIF(btrim(reason), '') IS NOT NULL),
  total_refund_minor bigint NOT NULL CHECK (total_refund_minor > 0),
  status text NOT NULL DEFAULT 'finalized'
    CHECK (status IN ('pending_approval', 'finalized', 'rejected')),
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  approval_id uuid REFERENCES approval_request(id),
  returned_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (business_id, store_id, return_number),
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE sale_return_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  sale_return_id uuid NOT NULL REFERENCES sale_return(id),
  sale_line_id uuid NOT NULL REFERENCES sale_line(id),
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  taxable_minor bigint NOT NULL CHECK (taxable_minor >= 0),
  cgst_minor bigint NOT NULL DEFAULT 0 CHECK (cgst_minor >= 0),
  sgst_minor bigint NOT NULL DEFAULT 0 CHECK (sgst_minor >= 0),
  igst_minor bigint NOT NULL DEFAULT 0 CHECK (igst_minor >= 0),
  tax_minor bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor > 0)
);

CREATE TABLE refund (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  shift_id uuid REFERENCES shift(id),
  sale_return_id uuid NOT NULL REFERENCES sale_return(id),
  method text NOT NULL
    CHECK (method IN ('cash', 'customer_credit', 'upi', 'card')),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  provider text,
  provider_reference text,
  status text NOT NULL DEFAULT 'captured'
    CHECK (status IN ('pending', 'captured', 'failed')),
  created_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key),
  CHECK (
    method IN ('cash', 'customer_credit')
    OR status <> 'captured'
    OR (provider IS NOT NULL AND provider_reference IS NOT NULL)
  )
);

CREATE INDEX sale_return_sale_time_idx
  ON sale_return (sale_id, returned_at, id);

CREATE INDEX sale_return_line_sale_line_idx
  ON sale_return_line (sale_line_id);

CREATE INDEX refund_shift_method_idx
  ON refund (shift_id, method, created_at);

ALTER TABLE sale_return ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_return_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund ENABLE ROW LEVEL SECURITY;

CREATE POLICY sale_return_tenant_isolation ON sale_return
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY sale_return_line_tenant_isolation ON sale_return_line
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY refund_tenant_isolation ON refund
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
