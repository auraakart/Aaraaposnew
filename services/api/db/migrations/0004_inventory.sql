BEGIN;

ALTER TABLE product
  ADD COLUMN reorder_level_milli bigint NOT NULL DEFAULT 0
    CHECK (reorder_level_milli >= 0);

CREATE TABLE stock_movement (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  product_id uuid NOT NULL REFERENCES product(id),
  movement_type text NOT NULL
    CHECK (
      movement_type IN (
        'opening',
        'receive',
        'sale',
        'return_in',
        'adjustment',
        'damage',
        'loss',
        'transfer_in',
        'transfer_out'
      )
    ),
  quantity_delta_milli bigint NOT NULL
    CHECK (quantity_delta_milli <> 0),
  reason text,
  source_entity_type text,
  source_entity_id uuid,
  actor_user_id uuid REFERENCES app_user(id),
  terminal_id uuid REFERENCES terminal(id),
  occurred_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (organization_id, idempotency_key),
  CHECK (
    movement_type NOT IN ('adjustment', 'damage', 'loss')
    OR NULLIF(btrim(reason), '') IS NOT NULL
  )
);

CREATE INDEX stock_movement_product_time_idx
  ON stock_movement (store_id, product_id, occurred_at, id);

ALTER TABLE stock_movement ENABLE ROW LEVEL SECURITY;

CREATE POLICY stock_movement_tenant_isolation ON stock_movement
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE VIEW stock_on_hand AS
SELECT
  organization_id,
  business_id,
  store_id,
  product_id,
  SUM(quantity_delta_milli) AS on_hand_milli
FROM stock_movement
GROUP BY organization_id, business_id, store_id, product_id;

COMMIT;
