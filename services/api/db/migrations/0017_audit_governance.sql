BEGIN;

ALTER TABLE audit_event
  ADD COLUMN terminal_id uuid REFERENCES terminal(id);

ALTER TABLE audit_event
  ADD COLUMN outcome text NOT NULL DEFAULT 'success'
    CHECK (outcome IN ('success', 'denied', 'failed'));

CREATE INDEX audit_event_terminal_time_idx
  ON audit_event (terminal_id, occurred_at DESC)
  WHERE terminal_id IS NOT NULL;

COMMIT;
