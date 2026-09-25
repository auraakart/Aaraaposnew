BEGIN;

CREATE TABLE product_category (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE product (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  category_id uuid REFERENCES product_category(id),
  name text NOT NULL,
  barcode text,
  unit_code text NOT NULL DEFAULT 'EA',
  selling_price_minor bigint NOT NULL CHECK (selling_price_minor >= 0),
  tax_rate_bps integer NOT NULL DEFAULT 0 CHECK (tax_rate_bps BETWEEN 0 AND 10000),
  tax_price_mode text NOT NULL DEFAULT 'inclusive'
    CHECK (tax_price_mode IN ('inclusive', 'exclusive')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, barcode)
);

CREATE TABLE sale (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  cashier_user_id uuid NOT NULL REFERENCES app_user(id),
  invoice_number text NOT NULL,
  local_created_at timestamptz NOT NULL,
  server_received_at timestamptz NOT NULL DEFAULT now(),
  tax_mode text NOT NULL CHECK (tax_mode IN ('intra_state', 'inter_state')),
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor >= 0),
  discount_minor bigint NOT NULL CHECK (discount_minor >= 0),
  tax_minor bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor >= 0),
  status text NOT NULL DEFAULT 'finalized'
    CHECK (status IN ('finalized', 'reversed')),
  idempotency_key text NOT NULL,
  UNIQUE (business_id, store_id, invoice_number),
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE sale_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  sale_id uuid NOT NULL REFERENCES sale(id),
  product_id uuid NOT NULL REFERENCES product(id),
  product_name_snapshot text NOT NULL,
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  unit_price_minor bigint NOT NULL CHECK (unit_price_minor >= 0),
  gross_minor bigint NOT NULL CHECK (gross_minor >= 0),
  discount_minor bigint NOT NULL CHECK (discount_minor >= 0),
  taxable_minor bigint NOT NULL CHECK (taxable_minor >= 0),
  cgst_minor bigint NOT NULL DEFAULT 0 CHECK (cgst_minor >= 0),
  sgst_minor bigint NOT NULL DEFAULT 0 CHECK (sgst_minor >= 0),
  igst_minor bigint NOT NULL DEFAULT 0 CHECK (igst_minor >= 0),
  tax_minor bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor >= 0)
);

CREATE TABLE payment (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  sale_id uuid NOT NULL REFERENCES sale(id),
  method text NOT NULL CHECK (method IN ('cash')),
  amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
  tendered_minor bigint,
  change_minor bigint,
  created_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE INDEX product_business_name_idx ON product (business_id, lower(name));
CREATE INDEX sale_store_created_idx ON sale (store_id, local_created_at DESC);

ALTER TABLE product_category ENABLE ROW LEVEL SECURITY;
ALTER TABLE product ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_category_tenant_isolation ON product_category
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY product_tenant_isolation ON product
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY sale_tenant_isolation ON sale
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY sale_line_tenant_isolation ON sale_line
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
CREATE POLICY payment_tenant_isolation ON payment
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);

COMMIT;
