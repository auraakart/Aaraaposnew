BEGIN;

ALTER TABLE store
  ADD COLUMN active boolean NOT NULL DEFAULT true;

ALTER TABLE store
  ADD CONSTRAINT store_scope_unique
  UNIQUE (id, organization_id, business_id);

CREATE TABLE user_store_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  user_id uuid NOT NULL REFERENCES app_user(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, store_id, user_id),
  FOREIGN KEY (store_id, organization_id, business_id)
    REFERENCES store(id, organization_id, business_id)
);

CREATE INDEX user_store_access_user_idx
  ON user_store_access (user_id, business_id, store_id);

ALTER TABLE user_store_access ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_store_access_tenant_isolation ON user_store_access
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE TABLE store_transfer (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  source_store_id uuid NOT NULL REFERENCES store(id),
  destination_store_id uuid NOT NULL REFERENCES store(id),
  transfer_number text NOT NULL,
  status text NOT NULL
    CHECK (status IN ('draft', 'dispatched', 'received', 'cancelled')),
  created_by_user_id uuid NOT NULL REFERENCES app_user(id),
  created_at timestamptz NOT NULL,
  dispatched_by_user_id uuid REFERENCES app_user(id),
  dispatched_at timestamptz,
  received_by_user_id uuid REFERENCES app_user(id),
  received_at timestamptz,
  cancelled_by_user_id uuid REFERENCES app_user(id),
  cancelled_at timestamptz,
  reason text,
  idempotency_key text NOT NULL,
  UNIQUE (business_id, transfer_number),
  UNIQUE (organization_id, idempotency_key),
  FOREIGN KEY (source_store_id, organization_id, business_id)
    REFERENCES store(id, organization_id, business_id),
  FOREIGN KEY (destination_store_id, organization_id, business_id)
    REFERENCES store(id, organization_id, business_id),
  CHECK (source_store_id <> destination_store_id),
  CHECK (
    (status = 'draft'
      AND dispatched_at IS NULL
      AND received_at IS NULL
      AND cancelled_at IS NULL)
    OR
    (status = 'dispatched'
      AND dispatched_at IS NOT NULL
      AND dispatched_by_user_id IS NOT NULL
      AND received_at IS NULL
      AND cancelled_at IS NULL)
    OR
    (status = 'received'
      AND dispatched_at IS NOT NULL
      AND dispatched_by_user_id IS NOT NULL
      AND received_at IS NOT NULL
      AND received_by_user_id IS NOT NULL
      AND cancelled_at IS NULL)
    OR
    (status = 'cancelled'
      AND dispatched_at IS NULL
      AND received_at IS NULL
      AND cancelled_at IS NOT NULL
      AND cancelled_by_user_id IS NOT NULL)
  )
);

CREATE TABLE store_transfer_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_transfer_id uuid NOT NULL REFERENCES store_transfer(id),
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  UNIQUE (store_transfer_id, product_id)
);

CREATE INDEX store_transfer_source_time_idx
  ON store_transfer (source_store_id, created_at DESC);

CREATE INDEX store_transfer_destination_time_idx
  ON store_transfer (destination_store_id, created_at DESC);

ALTER TABLE store_transfer ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_transfer_line ENABLE ROW LEVEL SECURITY;

CREATE POLICY store_transfer_tenant_isolation ON store_transfer
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY store_transfer_line_tenant_isolation ON store_transfer_line
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE VIEW store_business_summary
WITH (security_invoker = true) AS
SELECT
  st.organization_id,
  st.business_id,
  st.id AS store_id,
  st.name AS store_name,
  st.active,
  COALESCE((
    SELECT SUM(s.total_minor)
    FROM sale s
    WHERE s.store_id = st.id
      AND s.status = 'finalized'
  ), 0) AS lifetime_sales_minor,
  COALESCE((
    SELECT COUNT(*)
    FROM sale s
    WHERE s.store_id = st.id
      AND s.status = 'finalized'
  ), 0) AS lifetime_bill_count
FROM store st;

COMMIT;
