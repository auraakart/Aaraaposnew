BEGIN;

CREATE TABLE commerce_order (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  channel text NOT NULL
    CHECK (channel IN ('whatsapp', 'web', 'phone', 'manual')),
  status text NOT NULL
    CHECK (
      status IN ('received', 'confirmed', 'ready', 'completed', 'cancelled')
    ),
  customer_id uuid REFERENCES customer(id),
  external_conversation_ref text,
  note text,
  sale_id uuid UNIQUE REFERENCES sale(id),
  received_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  actor_user_id uuid REFERENCES app_user(id),
  idempotency_key text NOT NULL,
  UNIQUE (organization_id, idempotency_key),
  CHECK (
    (status = 'completed' AND sale_id IS NOT NULL)
    OR
    (status <> 'completed' AND sale_id IS NULL)
  )
);

CREATE TABLE commerce_order_line (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  commerce_order_id uuid NOT NULL
    REFERENCES commerce_order(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES product(id),
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  quoted_unit_price_minor bigint
    CHECK (quoted_unit_price_minor IS NULL OR quoted_unit_price_minor >= 0),
  UNIQUE (commerce_order_id, product_id)
);

CREATE TABLE commerce_inbound_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid REFERENCES store(id),
  provider_id uuid REFERENCES integration_provider(id),
  provider_event_id text NOT NULL,
  channel text NOT NULL CHECK (channel IN ('whatsapp', 'web')),
  external_conversation_ref text,
  payload_hash text NOT NULL,
  signature_valid boolean NOT NULL,
  timestamp_valid boolean NOT NULL,
  processing_state text NOT NULL
    CHECK (
      processing_state IN (
        'accepted',
        'duplicate',
        'rejected',
        'order_created',
        'ignored'
      )
    ),
  commerce_order_id uuid REFERENCES commerce_order(id),
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider_id, provider_event_id),
  CHECK (
    processing_state <> 'order_created'
    OR commerce_order_id IS NOT NULL
  )
);

CREATE INDEX commerce_order_store_status_time_idx
  ON commerce_order (store_id, status, received_at DESC);

CREATE INDEX commerce_order_customer_time_idx
  ON commerce_order (customer_id, received_at DESC)
  WHERE customer_id IS NOT NULL;

ALTER TABLE commerce_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE commerce_order_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE commerce_inbound_event ENABLE ROW LEVEL SECURITY;

CREATE POLICY commerce_order_tenant_isolation ON commerce_order
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY commerce_order_line_tenant_isolation ON commerce_order_line
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY commerce_inbound_event_tenant_isolation ON commerce_inbound_event
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
