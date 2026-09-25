BEGIN;

CREATE TABLE loyalty_program (
  business_id uuid PRIMARY KEY REFERENCES business(id),
  organization_id uuid NOT NULL REFERENCES organization(id),
  enabled boolean NOT NULL DEFAULT false,
  points_per_100_rupees integer NOT NULL DEFAULT 1
    CHECK (points_per_100_rupees >= 0),
  redemption_minor_per_point bigint NOT NULL DEFAULT 100
    CHECK (redemption_minor_per_point >= 0),
  max_redemption_bps integer NOT NULL DEFAULT 2000
    CHECK (max_redemption_bps BETWEEN 0 AND 10000),
  updated_by_user_id uuid NOT NULL REFERENCES app_user(id),
  updated_at timestamptz NOT NULL,
  CHECK (
    NOT enabled
    OR (
      points_per_100_rupees > 0
      AND redemption_minor_per_point > 0
    )
  )
);

CREATE TABLE customer_loyalty_entry (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  customer_id uuid NOT NULL REFERENCES customer(id),
  entry_type text NOT NULL
    CHECK (
      entry_type IN ('earn', 'redeem', 'adjustment_in', 'adjustment_out')
    ),
  points bigint NOT NULL CHECK (points > 0),
  sale_id uuid REFERENCES sale(id),
  note text,
  actor_user_id uuid NOT NULL REFERENCES app_user(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key),
  CHECK (
    entry_type NOT IN ('earn', 'redeem')
    OR sale_id IS NOT NULL
  )
);

CREATE INDEX customer_loyalty_customer_time_idx
  ON customer_loyalty_entry (customer_id, occurred_at, id);

CREATE TABLE promotion (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  name text NOT NULL,
  promotion_type text NOT NULL
    CHECK (promotion_type IN ('percentage', 'fixed')),
  value bigint NOT NULL CHECK (value > 0),
  min_basket_minor bigint NOT NULL DEFAULT 0 CHECK (min_basket_minor >= 0),
  max_discount_minor bigint CHECK (
    max_discount_minor IS NULL OR max_discount_minor >= 0
  ),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_by_user_id uuid NOT NULL REFERENCES app_user(id),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  CHECK (starts_at < ends_at),
  CHECK (
    promotion_type <> 'percentage'
    OR value BETWEEN 1 AND 10000
  )
);

CREATE TABLE promotion_product (
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  promotion_id uuid NOT NULL REFERENCES promotion(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES product(id),
  PRIMARY KEY (promotion_id, product_id)
);

CREATE TABLE promotion_redemption (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  promotion_id uuid NOT NULL REFERENCES promotion(id),
  customer_id uuid REFERENCES customer(id),
  sale_id uuid NOT NULL REFERENCES sale(id),
  discount_minor bigint NOT NULL CHECK (discount_minor > 0),
  redeemed_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key)
);

CREATE TABLE sale_loyalty (
  sale_id uuid PRIMARY KEY REFERENCES sale(id),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  customer_id uuid NOT NULL REFERENCES customer(id),
  points_redeemed bigint NOT NULL DEFAULT 0 CHECK (points_redeemed >= 0),
  redeemed_minor bigint NOT NULL DEFAULT 0 CHECK (redeemed_minor >= 0),
  points_earned bigint NOT NULL DEFAULT 0 CHECK (points_earned >= 0),
  CHECK (
    (points_redeemed = 0 AND redeemed_minor = 0)
    OR
    (points_redeemed > 0 AND redeemed_minor > 0)
  )
);

ALTER TABLE sale_line
  ADD COLUMN discount_source text
    CHECK (
      discount_source IS NULL
      OR discount_source IN ('manual', 'promotion', 'loyalty')
    ),
  ADD COLUMN discount_reference_id uuid;

ALTER TABLE loyalty_program ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_loyalty_entry ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_product ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_redemption ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_loyalty ENABLE ROW LEVEL SECURITY;

CREATE POLICY loyalty_program_tenant_isolation ON loyalty_program
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY customer_loyalty_tenant_isolation ON customer_loyalty_entry
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY promotion_tenant_isolation ON promotion
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY promotion_product_tenant_isolation ON promotion_product
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY promotion_redemption_tenant_isolation ON promotion_redemption
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY sale_loyalty_tenant_isolation ON sale_loyalty
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE VIEW customer_loyalty_balance
WITH (security_invoker = true) AS
SELECT
  organization_id,
  business_id,
  customer_id,
  SUM(
    CASE
      WHEN entry_type IN ('earn', 'adjustment_in') THEN points
      ELSE -points
    END
  ) AS points_balance
FROM customer_loyalty_entry
GROUP BY organization_id, business_id, customer_id;

COMMIT;
