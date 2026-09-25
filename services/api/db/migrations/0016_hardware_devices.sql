BEGIN;

CREATE TABLE hardware_device_profile (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  device_type text NOT NULL
    CHECK (
      device_type IN (
        'barcode_scanner',
        'receipt_printer',
        'cash_drawer',
        'weighing_scale',
        'customer_display',
        'payment_terminal'
      )
    ),
  connection_type text NOT NULL
    CHECK (
      connection_type IN (
        'built_in_camera',
        'keyboard_wedge',
        'bluetooth',
        'usb',
        'network',
        'provider'
      )
    ),
  status text NOT NULL
    CHECK (status IN ('configured', 'disabled', 'unavailable')),
  capabilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  config_reference text,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  UNIQUE (terminal_id, device_type, id),
  CHECK (
    status <> 'configured'
    OR connection_type IN ('built_in_camera', 'keyboard_wedge')
    OR config_reference IS NOT NULL
  )
);

CREATE TABLE hardware_command_audit (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organization(id),
  business_id uuid NOT NULL REFERENCES business(id),
  store_id uuid NOT NULL REFERENCES store(id),
  terminal_id uuid NOT NULL REFERENCES terminal(id),
  hardware_device_id uuid NOT NULL REFERENCES hardware_device_profile(id),
  capability text NOT NULL
    CHECK (
      capability IN (
        'scan_barcode',
        'print_receipt',
        'open_drawer',
        'read_weight',
        'display_total',
        'take_payment'
      )
    ),
  source_entity_type text,
  source_entity_id uuid,
  command_status text NOT NULL
    CHECK (
      command_status IN ('requested', 'succeeded', 'failed', 'cancelled')
    ),
  idempotency_key text NOT NULL,
  error_code text,
  occurred_at timestamptz NOT NULL,
  UNIQUE (organization_id, idempotency_key),
  CHECK (
    (source_entity_type IS NULL AND source_entity_id IS NULL)
    OR
    (source_entity_type IS NOT NULL AND source_entity_id IS NOT NULL)
  )
);

CREATE INDEX hardware_device_terminal_idx
  ON hardware_device_profile (terminal_id, device_type, status);

CREATE INDEX hardware_command_terminal_time_idx
  ON hardware_command_audit (terminal_id, occurred_at DESC);

ALTER TABLE hardware_device_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE hardware_command_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY hardware_device_tenant_isolation ON hardware_device_profile
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

CREATE POLICY hardware_command_tenant_isolation ON hardware_command_audit
  USING (
    organization_id =
      NULLIF(current_setting('app.organization_id', true), '')::uuid
  );

COMMIT;
