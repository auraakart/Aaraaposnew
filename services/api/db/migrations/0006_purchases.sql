BEGIN;

CREATE TABLE supplier (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  name text NOT NULL,
  mobile_e164 text,
  gstin text,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE INDEX supplier_business_name_idx
  ON supplier (business_id, lower(name));

ALTER TABLE supplier ENABLE ROW LEVEL SECURITY;

CREATE POLICY supplier_tenant_isolation ON supplier
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE TABLE purchase_order (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  supplier_id uuid NOT NULL REFERENCES supplier(id),
  status text NOT NULL
    CHECK (
      status IN (
        'draft',
        'ordered',
        'partially_received',
        'received',
        'cancelled'
      )
    ),
  order_number text NOT NULL,
  ordered_at timestamptz NOT NULL,
  expected_at timestamptz,
  note text,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  UNIQUE (business_id, store_id, order_number)
);

CREATE TABLE purchase_order_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  purchase_order_id uuid NOT NULL REFERENCES purchase_order(id),
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_ordered_milli bigint NOT NULL CHECK (quantity_ordered_milli > 0),
  quantity_received_milli bigint NOT NULL DEFAULT 0
    CHECK (
      quantity_received_milli >= 0
      AND quantity_received_milli <= quantity_ordered_milli
    ),
  unit_cost_minor bigint NOT NULL CHECK (unit_cost_minor > 0),
  tax_minor bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0)
);

CREATE TABLE purchase_receipt (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  supplier_id uuid NOT NULL REFERENCES supplier(id),
  purchase_order_id uuid REFERENCES purchase_order(id),
  supplier_invoice_number text,
  received_at timestamptz NOT NULL,
  total_minor bigint NOT NULL CHECK (total_minor > 0),
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE purchase_receipt_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  purchase_receipt_id uuid NOT NULL REFERENCES purchase_receipt(id),
  purchase_order_line_id uuid REFERENCES purchase_order_line(id),
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_received_milli bigint NOT NULL CHECK (quantity_received_milli > 0),
  unit_cost_minor bigint NOT NULL CHECK (unit_cost_minor > 0),
  tax_minor bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  line_total_minor bigint NOT NULL CHECK (line_total_minor > 0)
);

CREATE TABLE purchase_return (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  supplier_id uuid NOT NULL REFERENCES supplier(id),
  purchase_receipt_id uuid REFERENCES purchase_receipt(id),
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_returned_milli bigint NOT NULL CHECK (quantity_returned_milli > 0),
  credit_minor bigint NOT NULL CHECK (credit_minor > 0),
  reason text NOT NULL CHECK (NULLIF(btrim(reason), '') IS NOT NULL),
  returned_at timestamptz NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE supplier_ledger_entry (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  supplier_id uuid NOT NULL REFERENCES supplier(id),
  entry_type text NOT NULL
    CHECK (
      entry_type IN (
        'purchase_charge',
        'payment',
        'purchase_return_credit',
        'correction_increase',
        'correction_decrease'
      )
    ),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  source_id uuid,
  payment_method text
    CHECK (
      payment_method IS NULL OR payment_method IN ('cash', 'upi', 'card', 'bank')
    ),
  note text,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key),
  CHECK (entry_type <> 'payment' OR payment_method IS NOT NULL)
);

CREATE INDEX supplier_ledger_supplier_time_idx
  ON supplier_ledger_entry (supplier_id, occurred_at, id);

ALTER TABLE purchase_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_receipt ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_receipt_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_return ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_ledger_entry ENABLE ROW LEVEL SECURITY;

CREATE POLICY purchase_order_tenant_isolation ON purchase_order
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY purchase_order_line_tenant_isolation ON purchase_order_line
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY purchase_receipt_tenant_isolation ON purchase_receipt
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY purchase_receipt_line_tenant_isolation ON purchase_receipt_line
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY purchase_return_tenant_isolation ON purchase_return
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY supplier_ledger_tenant_isolation ON supplier_ledger_entry
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

CREATE VIEW supplier_balance
WITH (security_invoker = true) AS
SELECT
  organization_id,
  business_id,
  supplier_id,
  SUM(
    CASE
      WHEN entry_type IN ('purchase_charge', 'correction_increase')
        THEN amount_minor
      ELSE -amount_minor
    END
  ) AS balance_minor
FROM supplier_ledger_entry
GROUP BY organization_id, business_id, supplier_id;

COMMIT;
