BEGIN;

CREATE INDEX IF NOT EXISTS sale_business_created_idx
  ON sale (business_id, local_created_at DESC);

CREATE INDEX IF NOT EXISTS payment_sale_method_idx
  ON payment (sale_id, method);

CREATE INDEX IF NOT EXISTS expense_business_time_idx
  ON expense (business_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS customer_credit_business_time_idx
  ON customer_credit_entry (business_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS purchase_receipt_product_time_idx
  ON purchase_receipt_line (product_id, purchase_receipt_id);

CREATE INDEX IF NOT EXISTS shift_store_closed_idx
  ON shift (store_id, closed_at DESC)
  WHERE status = 'closed';

COMMIT;
