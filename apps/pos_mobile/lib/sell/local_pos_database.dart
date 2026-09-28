import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../accounting/accounting_domain.dart';
import '../audit/audit_domain.dart';
import '../ai/ai_domain.dart';
import '../commerce/commerce_domain.dart';
import '../customers/customer_domain.dart';
import '../diagnostics/diagnostics_domain.dart';
import '../intelligence/owner_intelligence.dart';
import '../inventory/inventory_domain.dart';
import '../loyalty/loyalty_domain.dart';
import '../operations/operations_domain.dart';
import '../purchases/purchase_domain.dart';
import '../sync/sync_domain.dart';
import 'return_domain.dart';
import 'sale_domain.dart';

class LocalSaleContext {
  const LocalSaleContext({
    required this.organizationId,
    required this.businessId,
    required this.storeId,
    required this.terminalId,
    required this.userId,
    required this.businessName,
    required this.storeName,
    required this.terminalCode,
    required this.taxMode,
    this.preferredLocaleCode,
  });

  final String organizationId;
  final String businessId;
  final String storeId;
  final String terminalId;
  final String userId;
  final String businessName;
  final String storeName;
  final String terminalCode;
  final TaxMode taxMode;
  final String? preferredLocaleCode;
}

class OfflineSaleResult {
  const OfflineSaleResult({
    required this.saleId,
    required this.invoiceNumber,
    required this.totalMinor,
    required this.tenderedMinor,
    required this.changeMinor,
    required this.receiptText,
    this.loyaltyPointsEarned = 0,
  });

  final String saleId;
  final String invoiceNumber;
  final int totalMinor;
  final int tenderedMinor;
  final int changeMinor;
  final String receiptText;
  final int loyaltyPointsEarned;
}

class LocalPosDatabase {
  LocalPosDatabase({
    DatabaseFactory? factory,
    String? databasePath,
    Uuid? uuid,
  })  : _factory = factory ?? databaseFactory,
        _databasePath = databasePath,
        _uuid = uuid ?? const Uuid();

  final DatabaseFactory _factory;
  final String? _databasePath;
  final Uuid _uuid;
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database is not open');
    }
    return db;
  }

  Future<void> open() async {
    if (_db != null) {
      return;
    }
    final path = _databasePath ??
        p.join(await getDatabasesPath(), 'aaraapos_local.db');

    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 14,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE local_context (
              singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
              organization_id TEXT NOT NULL,
              business_id TEXT NOT NULL,
              store_id TEXT NOT NULL,
              terminal_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              business_name TEXT NOT NULL,
              store_name TEXT NOT NULL,
              terminal_code TEXT NOT NULL,
              tax_mode TEXT NOT NULL,
              preferred_locale_code TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE product (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              barcode TEXT,
              unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
              tax_rate_bps INTEGER NOT NULL CHECK (tax_rate_bps BETWEEN 0 AND 10000),
              tax_price_mode TEXT NOT NULL,
              tax_classification_type TEXT,
              tax_classification_code TEXT,
              tax_rule_version_id TEXT,
              reorder_level_milli INTEGER NOT NULL DEFAULT 0,
              active INTEGER NOT NULL DEFAULT 1,
              UNIQUE (barcode)
            )
          ''');
          await db.execute('''
            CREATE TABLE customer (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              mobile_e164 TEXT,
              communication_consent TEXT NOT NULL DEFAULT 'unknown',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE terminal_sequence (
              terminal_code TEXT PRIMARY KEY,
              next_invoice INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sale (
              id TEXT PRIMARY KEY,
              organization_id TEXT NOT NULL,
              business_id TEXT NOT NULL,
              store_id TEXT NOT NULL,
              terminal_id TEXT NOT NULL,
              cashier_user_id TEXT NOT NULL,
              customer_id TEXT REFERENCES customer(id),
              shift_id TEXT REFERENCES shift(id),
              invoice_number TEXT NOT NULL UNIQUE,
              local_created_at TEXT NOT NULL,
              subtotal_minor INTEGER NOT NULL,
              discount_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL,
              total_minor INTEGER NOT NULL,
              status TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sale_line (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL REFERENCES sale(id),
              product_id TEXT NOT NULL,
              product_name_snapshot TEXT NOT NULL,
              quantity_milli INTEGER NOT NULL,
              unit_price_minor INTEGER NOT NULL,
              gross_minor INTEGER NOT NULL,
              discount_minor INTEGER NOT NULL,
              discount_source TEXT,
              discount_reference_id TEXT,
              taxable_minor INTEGER NOT NULL,
              cgst_minor INTEGER NOT NULL,
              sgst_minor INTEGER NOT NULL,
              igst_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL,
              total_minor INTEGER NOT NULL,
              tax_rate_bps_snapshot INTEGER,
              tax_price_mode_snapshot TEXT,
              tax_classification_type_snapshot TEXT,
              tax_classification_code_snapshot TEXT,
              tax_rule_version_id_snapshot TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE payment (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL REFERENCES sale(id),
              method TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              tendered_minor INTEGER NOT NULL,
              change_minor INTEGER NOT NULL,
              provider TEXT,
              provider_reference TEXT,
              status TEXT NOT NULL DEFAULT 'captured',
              reconciliation_status TEXT NOT NULL DEFAULT 'not_applicable',
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE payment_event (
              id TEXT PRIMARY KEY,
              payment_id TEXT NOT NULL REFERENCES payment(id),
              event_type TEXT NOT NULL,
              payment_status TEXT NOT NULL,
              provider_reference TEXT,
              amount_minor INTEGER NOT NULL,
              occurred_at TEXT NOT NULL,
              metadata_json TEXT NOT NULL DEFAULT '{}'
            )
          ''');
          await db.execute('''
            CREATE TABLE customer_credit_entry (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL REFERENCES customer(id),
              entry_type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
              sale_id TEXT REFERENCES sale(id),
              collection_method TEXT,
              due_date TEXT,
              shift_id TEXT REFERENCES shift(id),
              note TEXT,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE supplier (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              mobile_e164 TEXT,
              gstin TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE purchase_order (
              id TEXT PRIMARY KEY,
              supplier_id TEXT NOT NULL REFERENCES supplier(id),
              order_number TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL,
              ordered_at TEXT NOT NULL,
              note TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE purchase_order_line (
              id TEXT PRIMARY KEY,
              purchase_order_id TEXT NOT NULL REFERENCES purchase_order(id),
              product_id TEXT NOT NULL REFERENCES product(id),
              quantity_ordered_milli INTEGER NOT NULL,
              quantity_received_milli INTEGER NOT NULL DEFAULT 0,
              unit_cost_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE purchase_receipt (
              id TEXT PRIMARY KEY,
              supplier_id TEXT NOT NULL REFERENCES supplier(id),
              purchase_order_id TEXT REFERENCES purchase_order(id),
              supplier_invoice_number TEXT,
              received_at TEXT NOT NULL,
              total_minor INTEGER NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE purchase_receipt_line (
              id TEXT PRIMARY KEY,
              purchase_receipt_id TEXT NOT NULL REFERENCES purchase_receipt(id),
              purchase_order_line_id TEXT REFERENCES purchase_order_line(id),
              product_id TEXT NOT NULL REFERENCES product(id),
              quantity_received_milli INTEGER NOT NULL,
              unit_cost_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL DEFAULT 0,
              line_total_minor INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE purchase_return (
              id TEXT PRIMARY KEY,
              supplier_id TEXT NOT NULL REFERENCES supplier(id),
              purchase_receipt_id TEXT REFERENCES purchase_receipt(id),
              product_id TEXT NOT NULL REFERENCES product(id),
              quantity_returned_milli INTEGER NOT NULL,
              credit_minor INTEGER NOT NULL,
              reason TEXT NOT NULL,
              returned_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE supplier_ledger_entry (
              id TEXT PRIMARY KEY,
              supplier_id TEXT NOT NULL REFERENCES supplier(id),
              entry_type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              source_id TEXT,
              payment_method TEXT,
              note TEXT,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE employee (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              mobile_e164 TEXT,
              role TEXT NOT NULL,
              active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE shift (
              id TEXT PRIMARY KEY,
              employee_id TEXT NOT NULL REFERENCES employee(id),
              opened_at TEXT NOT NULL,
              opening_cash_minor INTEGER NOT NULL,
              closed_at TEXT,
              expected_closing_cash_minor INTEGER,
              actual_closing_cash_minor INTEGER,
              variance_minor INTEGER,
              status TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX shift_one_open_idx
            ON shift(status)
            WHERE status = 'open'
          ''');
          await db.execute('''
            CREATE TABLE cash_movement (
              id TEXT PRIMARY KEY,
              shift_id TEXT NOT NULL REFERENCES shift(id),
              movement_type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              reason TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE expense (
              id TEXT PRIMARY KEY,
              shift_id TEXT REFERENCES shift(id),
              category TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              payment_method TEXT NOT NULL,
              note TEXT,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE approval_request (
              id TEXT PRIMARY KEY,
              action_type TEXT NOT NULL,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              requested_by_employee_id TEXT NOT NULL REFERENCES employee(id),
              requested_at TEXT NOT NULL,
              status TEXT NOT NULL,
              resolved_by_employee_id TEXT REFERENCES employee(id),
              resolved_at TEXT,
              reason TEXT,
              action_fingerprint TEXT,
              requested_amount_minor INTEGER,
              expires_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE approval_consumption (
              id TEXT PRIMARY KEY,
              approval_request_id TEXT NOT NULL UNIQUE
                REFERENCES approval_request(id),
              consumed_by_employee_id TEXT NOT NULL REFERENCES employee(id),
              action_fingerprint TEXT NOT NULL,
              consumed_at TEXT NOT NULL,
              request_id TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE held_sale (
              id TEXT PRIMARY KEY,
              customer_id TEXT REFERENCES customer(id),
              held_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE held_sale_line (
              id TEXT PRIMARY KEY,
              held_sale_id TEXT NOT NULL REFERENCES held_sale(id) ON DELETE CASCADE,
              product_id TEXT NOT NULL REFERENCES product(id),
              product_name_snapshot TEXT NOT NULL,
              quantity_milli INTEGER NOT NULL,
              unit_price_minor INTEGER NOT NULL,
              discount_minor INTEGER NOT NULL DEFAULT 0,
              discount_source TEXT,
              discount_reference_id TEXT,
              tax_rate_bps INTEGER NOT NULL,
              tax_price_mode TEXT NOT NULL,
              tax_classification_type TEXT,
              tax_classification_code TEXT,
              tax_rule_version_id TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE return_sequence (
              terminal_code TEXT PRIMARY KEY,
              next_return INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sale_return (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL REFERENCES sale(id),
              return_number TEXT NOT NULL UNIQUE,
              reason TEXT NOT NULL,
              total_refund_minor INTEGER NOT NULL,
              status TEXT NOT NULL,
              returned_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE sale_return_line (
              id TEXT PRIMARY KEY,
              sale_return_id TEXT NOT NULL REFERENCES sale_return(id),
              sale_line_id TEXT NOT NULL REFERENCES sale_line(id),
              product_id TEXT NOT NULL REFERENCES product(id),
              quantity_milli INTEGER NOT NULL,
              taxable_minor INTEGER NOT NULL,
              cgst_minor INTEGER NOT NULL,
              sgst_minor INTEGER NOT NULL,
              igst_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL,
              total_minor INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE refund (
              id TEXT PRIMARY KEY,
              sale_return_id TEXT NOT NULL REFERENCES sale_return(id),
              shift_id TEXT REFERENCES shift(id),
              method TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE loyalty_program (
              singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
              enabled INTEGER NOT NULL DEFAULT 0,
              points_per_100_rupees INTEGER NOT NULL DEFAULT 1,
              redemption_minor_per_point INTEGER NOT NULL DEFAULT 100,
              max_redemption_bps INTEGER NOT NULL DEFAULT 2000,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE customer_loyalty_entry (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL REFERENCES customer(id),
              entry_type TEXT NOT NULL,
              points INTEGER NOT NULL,
              sale_id TEXT REFERENCES sale(id),
              note TEXT,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE promotion (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              promotion_type TEXT NOT NULL,
              value INTEGER NOT NULL,
              min_basket_minor INTEGER NOT NULL DEFAULT 0,
              max_discount_minor INTEGER,
              starts_at TEXT NOT NULL,
              ends_at TEXT NOT NULL,
              active INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE promotion_product (
              promotion_id TEXT NOT NULL REFERENCES promotion(id) ON DELETE CASCADE,
              product_id TEXT NOT NULL REFERENCES product(id),
              PRIMARY KEY (promotion_id, product_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE promotion_redemption (
              id TEXT PRIMARY KEY,
              promotion_id TEXT NOT NULL REFERENCES promotion(id),
              customer_id TEXT REFERENCES customer(id),
              sale_id TEXT NOT NULL REFERENCES sale(id),
              discount_minor INTEGER NOT NULL,
              redeemed_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE sale_loyalty (
              sale_id TEXT PRIMARY KEY REFERENCES sale(id),
              customer_id TEXT NOT NULL REFERENCES customer(id),
              points_earned INTEGER NOT NULL DEFAULT 0,
              points_redeemed INTEGER NOT NULL DEFAULT 0,
              redeemed_minor INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE stock_movement (
              id TEXT PRIMARY KEY,
              product_id TEXT NOT NULL REFERENCES product(id),
              movement_type TEXT NOT NULL,
              quantity_delta_milli INTEGER NOT NULL,
              reason TEXT,
              source_entity_type TEXT,
              source_entity_id TEXT,
              occurred_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_outbox (
              id TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              organization_id TEXT NOT NULL,
              business_id TEXT NOT NULL,
              store_id TEXT NOT NULL,
              terminal_id TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE,
              payload_json TEXT NOT NULL,
              schema_version INTEGER NOT NULL DEFAULT 1,
              state TEXT NOT NULL,
              created_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_attempt_at TEXT,
              last_error TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE local_audit_event (
              id TEXT PRIMARY KEY,
              actor_user_id TEXT NOT NULL,
              action TEXT NOT NULL,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              outcome TEXT NOT NULL,
              metadata_json TEXT NOT NULL DEFAULT '{}'
            )
          ''');
          await db.execute('''
            CREATE INDEX local_audit_time_idx
            ON local_audit_event (occurred_at DESC)
          ''');
          await db.execute('''
            CREATE TABLE commerce_order (
              id TEXT PRIMARY KEY,
              channel TEXT NOT NULL,
              status TEXT NOT NULL,
              customer_id TEXT REFERENCES customer(id),
              external_conversation_ref TEXT,
              note TEXT,
              sale_id TEXT UNIQUE REFERENCES sale(id),
              received_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE commerce_order_line (
              id TEXT PRIMARY KEY,
              commerce_order_id TEXT NOT NULL
                REFERENCES commerce_order(id) ON DELETE CASCADE,
              product_id TEXT NOT NULL REFERENCES product(id),
              quantity_milli INTEGER NOT NULL,
              quoted_unit_price_minor INTEGER NOT NULL,
              UNIQUE (commerce_order_id, product_id)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE payment ADD COLUMN provider TEXT",
            );
            await db.execute(
              "ALTER TABLE payment ADD COLUMN provider_reference TEXT",
            );
            await db.execute(
              "ALTER TABLE payment ADD COLUMN status TEXT NOT NULL DEFAULT 'captured'",
            );
            await db.execute(
              "ALTER TABLE payment ADD COLUMN reconciliation_status TEXT NOT NULL DEFAULT 'not_applicable'",
            );
            await db.execute('''
              CREATE TABLE payment_event (
                id TEXT PRIMARY KEY,
                payment_id TEXT NOT NULL REFERENCES payment(id),
                event_type TEXT NOT NULL,
                payment_status TEXT NOT NULL,
                provider_reference TEXT,
                amount_minor INTEGER NOT NULL,
                occurred_at TEXT NOT NULL,
                metadata_json TEXT NOT NULL DEFAULT '{}'
              )
            ''');
          }
          if (oldVersion < 3) {
            await db.execute(
              "ALTER TABLE product ADD COLUMN reorder_level_milli INTEGER NOT NULL DEFAULT 0",
            );
            await db.execute('''
              CREATE TABLE stock_movement (
                id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL REFERENCES product(id),
                movement_type TEXT NOT NULL,
                quantity_delta_milli INTEGER NOT NULL,
                reason TEXT,
                source_entity_type TEXT,
                source_entity_id TEXT,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE customer (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                mobile_e164 TEXT,
                communication_consent TEXT NOT NULL DEFAULT 'unknown',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute(
              "ALTER TABLE sale ADD COLUMN customer_id TEXT REFERENCES customer(id)",
            );
            await db.execute('''
              CREATE TABLE customer_credit_entry (
                id TEXT PRIMARY KEY,
                customer_id TEXT NOT NULL REFERENCES customer(id),
                entry_type TEXT NOT NULL,
                amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
                sale_id TEXT REFERENCES sale(id),
                collection_method TEXT,
                due_date TEXT,
                note TEXT,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
          }
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE supplier (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                mobile_e164 TEXT,
                gstin TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE purchase_order (
                id TEXT PRIMARY KEY,
                supplier_id TEXT NOT NULL REFERENCES supplier(id),
                order_number TEXT NOT NULL UNIQUE,
                status TEXT NOT NULL,
                ordered_at TEXT NOT NULL,
                note TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE purchase_order_line (
                id TEXT PRIMARY KEY,
                purchase_order_id TEXT NOT NULL REFERENCES purchase_order(id),
                product_id TEXT NOT NULL REFERENCES product(id),
                quantity_ordered_milli INTEGER NOT NULL,
                quantity_received_milli INTEGER NOT NULL DEFAULT 0,
                unit_cost_minor INTEGER NOT NULL,
                tax_minor INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE purchase_receipt (
                id TEXT PRIMARY KEY,
                supplier_id TEXT NOT NULL REFERENCES supplier(id),
                purchase_order_id TEXT REFERENCES purchase_order(id),
                supplier_invoice_number TEXT,
                received_at TEXT NOT NULL,
                total_minor INTEGER NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE purchase_receipt_line (
                id TEXT PRIMARY KEY,
                purchase_receipt_id TEXT NOT NULL REFERENCES purchase_receipt(id),
                purchase_order_line_id TEXT REFERENCES purchase_order_line(id),
                product_id TEXT NOT NULL REFERENCES product(id),
                quantity_received_milli INTEGER NOT NULL,
                unit_cost_minor INTEGER NOT NULL,
                tax_minor INTEGER NOT NULL DEFAULT 0,
                line_total_minor INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE purchase_return (
                id TEXT PRIMARY KEY,
                supplier_id TEXT NOT NULL REFERENCES supplier(id),
                purchase_receipt_id TEXT REFERENCES purchase_receipt(id),
                product_id TEXT NOT NULL REFERENCES product(id),
                quantity_returned_milli INTEGER NOT NULL,
                credit_minor INTEGER NOT NULL,
                reason TEXT NOT NULL,
                returned_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE supplier_ledger_entry (
                id TEXT PRIMARY KEY,
                supplier_id TEXT NOT NULL REFERENCES supplier(id),
                entry_type TEXT NOT NULL,
                amount_minor INTEGER NOT NULL,
                source_id TEXT,
                payment_method TEXT,
                note TEXT,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
          }
          if (oldVersion < 6) {
            await db.execute('''
              CREATE TABLE employee (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                mobile_e164 TEXT,
                role TEXT NOT NULL,
                active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE shift (
                id TEXT PRIMARY KEY,
                employee_id TEXT NOT NULL REFERENCES employee(id),
                opened_at TEXT NOT NULL,
                opening_cash_minor INTEGER NOT NULL,
                closed_at TEXT,
                expected_closing_cash_minor INTEGER,
                actual_closing_cash_minor INTEGER,
                variance_minor INTEGER,
                status TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE UNIQUE INDEX shift_one_open_idx
              ON shift(status)
              WHERE status = 'open'
            ''');
            await db.execute('''
              CREATE TABLE cash_movement (
                id TEXT PRIMARY KEY,
                shift_id TEXT NOT NULL REFERENCES shift(id),
                movement_type TEXT NOT NULL,
                amount_minor INTEGER NOT NULL,
                reason TEXT NOT NULL,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE expense (
                id TEXT PRIMARY KEY,
                shift_id TEXT REFERENCES shift(id),
                category TEXT NOT NULL,
                amount_minor INTEGER NOT NULL,
                payment_method TEXT NOT NULL,
                note TEXT,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE approval_request (
                id TEXT PRIMARY KEY,
                action_type TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                requested_by_employee_id TEXT NOT NULL REFERENCES employee(id),
                requested_at TEXT NOT NULL,
                status TEXT NOT NULL,
                resolved_by_employee_id TEXT REFERENCES employee(id),
                resolved_at TEXT,
                reason TEXT
              )
            ''');
            await db.execute(
              "ALTER TABLE sale ADD COLUMN shift_id TEXT REFERENCES shift(id)",
            );
            await db.execute(
              "ALTER TABLE customer_credit_entry ADD COLUMN shift_id TEXT REFERENCES shift(id)",
            );
            await db.execute('''
              INSERT OR IGNORE INTO employee (
                id, name, role, active, created_at
              )
              SELECT user_id, 'Owner', 'owner', 1, CURRENT_TIMESTAMP
              FROM local_context
              WHERE singleton_id = 1
            ''');
          }
          if (oldVersion < 7) {
            await db.execute('''
              CREATE TABLE held_sale (
                id TEXT PRIMARY KEY,
                customer_id TEXT REFERENCES customer(id),
                held_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE held_sale_line (
                id TEXT PRIMARY KEY,
                held_sale_id TEXT NOT NULL REFERENCES held_sale(id) ON DELETE CASCADE,
                product_id TEXT NOT NULL REFERENCES product(id),
                product_name_snapshot TEXT NOT NULL,
                quantity_milli INTEGER NOT NULL,
                unit_price_minor INTEGER NOT NULL,
                discount_minor INTEGER NOT NULL DEFAULT 0,
                tax_rate_bps INTEGER NOT NULL,
                tax_price_mode TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE return_sequence (
                terminal_code TEXT PRIMARY KEY,
                next_return INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              INSERT OR IGNORE INTO return_sequence (terminal_code, next_return)
              SELECT terminal_code, 1 FROM local_context WHERE singleton_id = 1
            ''');
            await db.execute('''
              CREATE TABLE sale_return (
                id TEXT PRIMARY KEY,
                sale_id TEXT NOT NULL REFERENCES sale(id),
                return_number TEXT NOT NULL UNIQUE,
                reason TEXT NOT NULL,
                total_refund_minor INTEGER NOT NULL,
                status TEXT NOT NULL,
                returned_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE sale_return_line (
                id TEXT PRIMARY KEY,
                sale_return_id TEXT NOT NULL REFERENCES sale_return(id),
                sale_line_id TEXT NOT NULL REFERENCES sale_line(id),
                product_id TEXT NOT NULL REFERENCES product(id),
                quantity_milli INTEGER NOT NULL,
                taxable_minor INTEGER NOT NULL,
                cgst_minor INTEGER NOT NULL,
                sgst_minor INTEGER NOT NULL,
                igst_minor INTEGER NOT NULL,
                tax_minor INTEGER NOT NULL,
                total_minor INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE refund (
                id TEXT PRIMARY KEY,
                sale_return_id TEXT NOT NULL REFERENCES sale_return(id),
                shift_id TEXT REFERENCES shift(id),
                method TEXT NOT NULL,
                amount_minor INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
          }
          if (oldVersion < 8) {
            await db.execute(
              "ALTER TABLE sale_line ADD COLUMN discount_source TEXT",
            );
            await db.execute(
              "ALTER TABLE sale_line ADD COLUMN discount_reference_id TEXT",
            );
            await db.execute(
              "ALTER TABLE held_sale_line ADD COLUMN discount_source TEXT",
            );
            await db.execute(
              "ALTER TABLE held_sale_line ADD COLUMN discount_reference_id TEXT",
            );
            await db.execute('''
              CREATE TABLE loyalty_program (
                singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
                enabled INTEGER NOT NULL DEFAULT 0,
                points_per_100_rupees INTEGER NOT NULL DEFAULT 1,
                redemption_minor_per_point INTEGER NOT NULL DEFAULT 100,
                max_redemption_bps INTEGER NOT NULL DEFAULT 2000,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE customer_loyalty_entry (
                id TEXT PRIMARY KEY,
                customer_id TEXT NOT NULL REFERENCES customer(id),
                entry_type TEXT NOT NULL,
                points INTEGER NOT NULL,
                sale_id TEXT REFERENCES sale(id),
                note TEXT,
                occurred_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE promotion (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                promotion_type TEXT NOT NULL,
                value INTEGER NOT NULL,
                min_basket_minor INTEGER NOT NULL DEFAULT 0,
                max_discount_minor INTEGER,
                starts_at TEXT NOT NULL,
                ends_at TEXT NOT NULL,
                active INTEGER NOT NULL DEFAULT 1
              )
            ''');
            await db.execute('''
              CREATE TABLE promotion_product (
                promotion_id TEXT NOT NULL REFERENCES promotion(id) ON DELETE CASCADE,
                product_id TEXT NOT NULL REFERENCES product(id),
                PRIMARY KEY (promotion_id, product_id)
              )
            ''');
            await db.execute('''
              CREATE TABLE promotion_redemption (
                id TEXT PRIMARY KEY,
                promotion_id TEXT NOT NULL REFERENCES promotion(id),
                customer_id TEXT REFERENCES customer(id),
                sale_id TEXT NOT NULL REFERENCES sale(id),
                discount_minor INTEGER NOT NULL,
                redeemed_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE sale_loyalty (
                sale_id TEXT PRIMARY KEY REFERENCES sale(id),
                customer_id TEXT NOT NULL REFERENCES customer(id),
                points_earned INTEGER NOT NULL DEFAULT 0,
                points_redeemed INTEGER NOT NULL DEFAULT 0,
                redeemed_minor INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.insert('loyalty_program', {
              'singleton_id': 1,
              'enabled': 0,
              'points_per_100_rupees': 1,
              'redemption_minor_per_point': 100,
              'max_redemption_bps': 2000,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
          if (oldVersion < 9) {
            await db.execute(
              "ALTER TABLE sync_outbox ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1",
            );
            await db.execute(
              "ALTER TABLE sync_outbox ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE sync_outbox ADD COLUMN last_attempt_at TEXT",
            );
          }
          if (oldVersion < 10) {
            await db.execute('''
              CREATE TABLE commerce_order (
                id TEXT PRIMARY KEY,
                channel TEXT NOT NULL,
                status TEXT NOT NULL,
                customer_id TEXT REFERENCES customer(id),
                external_conversation_ref TEXT,
                note TEXT,
                sale_id TEXT UNIQUE REFERENCES sale(id),
                received_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                idempotency_key TEXT NOT NULL UNIQUE
              )
            ''');
            await db.execute('''
              CREATE TABLE commerce_order_line (
                id TEXT PRIMARY KEY,
                commerce_order_id TEXT NOT NULL
                  REFERENCES commerce_order(id) ON DELETE CASCADE,
                product_id TEXT NOT NULL REFERENCES product(id),
                quantity_milli INTEGER NOT NULL,
                quoted_unit_price_minor INTEGER NOT NULL,
                UNIQUE (commerce_order_id, product_id)
              )
            ''');
          }
          if (oldVersion < 11) {
            await db.execute(
              "ALTER TABLE local_context ADD COLUMN preferred_locale_code TEXT",
            );
          }
          if (oldVersion < 12) {
            await db.execute('''
              CREATE TABLE local_audit_event (
                id TEXT PRIMARY KEY,
                actor_user_id TEXT NOT NULL,
                action TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                occurred_at TEXT NOT NULL,
                outcome TEXT NOT NULL,
                metadata_json TEXT NOT NULL DEFAULT '{}'
              )
            ''');
            await db.execute('''
              CREATE INDEX local_audit_time_idx
              ON local_audit_event (occurred_at DESC)
            ''');
          }
          if (oldVersion < 13) {
            await db.execute(
              'ALTER TABLE product ADD COLUMN tax_classification_type TEXT',
            );
            await db.execute(
              'ALTER TABLE product ADD COLUMN tax_classification_code TEXT',
            );
            await db.execute(
              'ALTER TABLE product ADD COLUMN tax_rule_version_id TEXT',
            );
            await db.execute(
              'ALTER TABLE sale_line ADD COLUMN tax_rate_bps_snapshot INTEGER',
            );
            await db.execute(
              'ALTER TABLE sale_line ADD COLUMN tax_price_mode_snapshot TEXT',
            );
            await db.execute(
              'ALTER TABLE sale_line ADD COLUMN tax_classification_type_snapshot TEXT',
            );
            await db.execute(
              'ALTER TABLE sale_line ADD COLUMN tax_classification_code_snapshot TEXT',
            );
            await db.execute(
              'ALTER TABLE sale_line ADD COLUMN tax_rule_version_id_snapshot TEXT',
            );
            await db.execute(
              'ALTER TABLE held_sale_line ADD COLUMN tax_classification_type TEXT',
            );
            await db.execute(
              'ALTER TABLE held_sale_line ADD COLUMN tax_classification_code TEXT',
            );
            await db.execute(
              'ALTER TABLE held_sale_line ADD COLUMN tax_rule_version_id TEXT',
            );
          }
          if (oldVersion < 14) {
            await db.execute(
              'ALTER TABLE approval_request ADD COLUMN action_fingerprint TEXT',
            );
            await db.execute(
              'ALTER TABLE approval_request ADD COLUMN requested_amount_minor INTEGER',
            );
            await db.execute(
              'ALTER TABLE approval_request ADD COLUMN expires_at TEXT',
            );
            await db.execute('''
              CREATE TABLE approval_consumption (
                id TEXT PRIMARY KEY,
                approval_request_id TEXT NOT NULL UNIQUE
                  REFERENCES approval_request(id),
                consumed_by_employee_id TEXT NOT NULL REFERENCES employee(id),
                action_fingerprint TEXT NOT NULL,
                consumed_at TEXT NOT NULL,
                request_id TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE INDEX approval_request_status_time_idx
              ON approval_request (status, requested_at DESC)
            ''');
          }
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<LocalSaleContext?> loadContext() async {
    final rows = await _database.query(
      'local_context',
      where: 'singleton_id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return LocalSaleContext(
      organizationId: row['organization_id']! as String,
      businessId: row['business_id']! as String,
      storeId: row['store_id']! as String,
      terminalId: row['terminal_id']! as String,
      userId: row['user_id']! as String,
      businessName: row['business_name']! as String,
      storeName: row['store_name']! as String,
      terminalCode: row['terminal_code']! as String,
      taxMode: row['tax_mode'] == 'inter_state'
          ? TaxMode.interState
          : TaxMode.intraState,
      preferredLocaleCode: row['preferred_locale_code'] as String?,
    );
  }

  Future<LocalSaleContext> bootstrapOwner({
    required String businessName,
    required String storeName,
  }) async {
    final normalizedBusiness = businessName.trim();
    final normalizedStore = storeName.trim();
    if (normalizedBusiness.isEmpty || normalizedStore.isEmpty) {
      throw ArgumentError('Business and store names are required');
    }

    final context = LocalSaleContext(
      organizationId: _uuid.v4(),
      businessId: _uuid.v4(),
      storeId: _uuid.v4(),
      terminalId: _uuid.v4(),
      userId: _uuid.v4(),
      businessName: normalizedBusiness,
      storeName: normalizedStore,
      terminalCode: 'T01',
      taxMode: TaxMode.intraState,
    );

    await _database.transaction((txn) async {
      await txn.insert('local_context', {
        'singleton_id': 1,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'user_id': context.userId,
        'business_name': context.businessName,
        'store_name': context.storeName,
        'terminal_code': context.terminalCode,
        'tax_mode': 'intra_state',
      });
      await txn.insert('terminal_sequence', {
        'terminal_code': context.terminalCode,
        'next_invoice': 1,
      });
      await txn.insert('return_sequence', {
        'terminal_code': context.terminalCode,
        'next_return': 1,
      });
      await txn.insert('employee', {
        'id': context.userId,
        'name': 'Owner',
        'role': 'owner',
        'active': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.insert('loyalty_program', {
        'singleton_id': 1,
        'enabled': 0,
        'points_per_100_rupees': 1,
        'redemption_minor_per_point': 100,
        'max_redemption_bps': 2000,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    return context;
  }

  Future<void> updatePreferredLocaleCode(String? localeCode) async {
    final normalized = localeCode?.trim().toLowerCase();
    if (normalized != null &&
        normalized.isNotEmpty &&
        !{'en', 'hi', 'ta'}.contains(normalized)) {
      throw ArgumentError('Unsupported locale code');
    }
    await _database.update(
      'local_context',
      {
        'preferred_locale_code':
            normalized == null || normalized.isEmpty ? null : normalized,
      },
      where: 'singleton_id = 1',
    );
  }

  Future<List<Product>> listProducts({String query = ''}) async {
    final trimmed = query.trim();
    final rows = trimmed.isEmpty
        ? await _database.query(
            'product',
            where: 'active = 1',
            orderBy: 'name COLLATE NOCASE',
          )
        : await _database.query(
            'product',
            where: 'active = 1 AND (name LIKE ? OR barcode = ?)',
            whereArgs: ['%$trimmed%', trimmed],
            orderBy: 'name COLLATE NOCASE',
          );

    return rows
        .map(
          (row) => Product(
            id: row['id']! as String,
            name: row['name']! as String,
            barcode: row['barcode'] as String?,
            unitPriceMinor: row['unit_price_minor']! as int,
            taxRateBps: row['tax_rate_bps']! as int,
            taxPriceMode: row['tax_price_mode'] == 'exclusive'
                ? TaxPriceMode.exclusive
                : TaxPriceMode.inclusive,
            taxClassificationType: taxClassificationTypeFromValue(
              row['tax_classification_type'] as String?,
            ),
            taxClassificationCode: row['tax_classification_code'] as String?,
            taxRuleVersionId: row['tax_rule_version_id'] as String?,
          ),
        )
        .toList();
  }

  Future<Product> addProduct({
    required String name,
    required int unitPriceMinor,
    String? barcode,
    int taxRateBps = 0,
    TaxPriceMode taxPriceMode = TaxPriceMode.inclusive,
    TaxClassificationType? taxClassificationType,
    String? taxClassificationCode,
    String? taxRuleVersionId,
    int reorderLevelMilli = 0,
  }) async {
    final trimmed = name.trim();
    final normalizedClassification = taxClassificationCode?.trim();
    final normalizedRuleVersion = taxRuleVersionId?.trim();
    final hasClassificationType = taxClassificationType != null;
    final hasClassificationCode =
        normalizedClassification != null && normalizedClassification.isNotEmpty;
    final validClassificationCode = !hasClassificationCode ||
        RegExp(r'^[A-Za-z0-9.-]{2,32}$').hasMatch(
          normalizedClassification,
        );

    if (trimmed.isEmpty ||
        unitPriceMinor < 0 ||
        taxRateBps < 0 ||
        taxRateBps > 10000 ||
        reorderLevelMilli < 0 ||
        hasClassificationType != hasClassificationCode ||
        !validClassificationCode) {
      throw ArgumentError('Invalid product');
    }

    final product = Product(
      id: _uuid.v4(),
      name: trimmed,
      barcode: barcode?.trim().isEmpty ?? true ? null : barcode!.trim(),
      unitPriceMinor: unitPriceMinor,
      taxRateBps: taxRateBps,
      taxPriceMode: taxPriceMode,
      taxClassificationType: taxClassificationType,
      taxClassificationCode:
          hasClassificationCode ? normalizedClassification : null,
      taxRuleVersionId:
          normalizedRuleVersion?.isEmpty ?? true ? null : normalizedRuleVersion,
    );
    await _database.insert('product', {
      'id': product.id,
      'name': product.name,
      'barcode': product.barcode,
      'unit_price_minor': product.unitPriceMinor,
      'tax_rate_bps': product.taxRateBps,
      'tax_price_mode': product.taxPriceMode == TaxPriceMode.exclusive
          ? 'exclusive'
          : 'inclusive',
      'tax_classification_type': product.taxClassificationType == null
          ? null
          : taxClassificationTypeValue(product.taxClassificationType!),
      'tax_classification_code': product.taxClassificationCode,
      'tax_rule_version_id': product.taxRuleVersionId,
      'reorder_level_milli': reorderLevelMilli,
      'active': 1,
    });
    return product;
  }

  Future<String> createCommerceOrder({
    required LocalSaleContext context,
    required CommerceChannel channel,
    required List<SaleLineInput> lines,
    String? customerId,
    String? externalConversationRef,
    String? note,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Order requires at least one item');
    }
    final productIds = <String>{};
    for (final line in lines) {
      if (line.quantityMilli <= 0 || !productIds.add(line.product.id)) {
        throw ArgumentError('Invalid or duplicate order item');
      }
    }

    final orderId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction((txn) async {
      if (customerId != null) {
        final customers = await txn.query(
          'customer',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customers.isEmpty) throw StateError('Customer not found');
      }
      await txn.insert('commerce_order', {
        'id': orderId,
        'channel': commerceChannelValue(channel),
        'status': 'received',
        'customer_id': customerId,
        'external_conversation_ref':
            externalConversationRef?.trim().isEmpty ?? true
                ? null
                : externalConversationRef!.trim(),
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
        'received_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });
      for (final line in lines) {
        await txn.insert('commerce_order_line', {
          'id': _uuid.v4(),
          'commerce_order_id': orderId,
          'product_id': line.product.id,
          'quantity_milli': line.quantityMilli,
          'quoted_unit_price_minor': line.product.unitPriceMinor,
        });
      }
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'commerce_order',
        'entity_id': orderId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'commerceOrderId': orderId,
          'channel': commerceChannelValue(channel),
          'status': 'received',
          'customerId': customerId,
          'externalConversationRef': externalConversationRef?.trim(),
          'note': note?.trim(),
          'receivedAt': now.toIso8601String(),
          'lines': [
            for (final line in lines)
              {
                'productId': line.product.id,
                'quantityMilli': line.quantityMilli,
                'quotedUnitPriceMinor': line.product.unitPriceMinor,
              },
          ],
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });

    return orderId;
  }

  Future<List<LocalCommerceOrder>> listCommerceOrders({
    bool includeClosed = true,
  }) async {
    final customers = {
      for (final customer in await listCustomers()) customer.id: customer,
    };
    final headers = await _database.query(
      'commerce_order',
      where: includeClosed
          ? null
          : "status NOT IN ('completed', 'cancelled')",
      orderBy: 'received_at DESC',
    );
    final result = <LocalCommerceOrder>[];
    for (final header in headers) {
      final orderId = header['id']! as String;
      final lineRows = await _database.rawQuery(
        '''
        SELECT
          col.quantity_milli,
          col.quoted_unit_price_minor,
          p.*
        FROM commerce_order_line col
        INNER JOIN product p ON p.id = col.product_id
        WHERE col.commerce_order_id = ?
        ORDER BY p.name COLLATE NOCASE
        ''',
        [orderId],
      );
      final lines = lineRows
          .map(
            (row) => CommerceOrderLine(
              product: Product(
                id: row['id']! as String,
                name: row['name']! as String,
                barcode: row['barcode'] as String?,
                unitPriceMinor: row['unit_price_minor']! as int,
                taxRateBps: row['tax_rate_bps']! as int,
                taxPriceMode: row['tax_price_mode'] == 'exclusive'
                    ? TaxPriceMode.exclusive
                    : TaxPriceMode.inclusive,
                taxClassificationType: taxClassificationTypeFromValue(
                  row['tax_classification_type'] as String?,
                ),
                taxClassificationCode:
                    row['tax_classification_code'] as String?,
                taxRuleVersionId: row['tax_rule_version_id'] as String?,
              ),
              quantityMilli: row['quantity_milli']! as int,
              quotedUnitPriceMinor:
                  row['quoted_unit_price_minor']! as int,
            ),
          )
          .toList();
      result.add(
        LocalCommerceOrder(
          id: orderId,
          channel: commerceChannelFromValue(header['channel']! as String),
          status:
              commerceOrderStatusFromValue(header['status']! as String),
          receivedAt: DateTime.parse(header['received_at']! as String),
          lines: lines,
          customer: customers[header['customer_id'] as String?],
          externalConversationRef:
              header['external_conversation_ref'] as String?,
          note: header['note'] as String?,
          saleId: header['sale_id'] as String?,
        ),
      );
    }
    return result;
  }

  Future<void> transitionCommerceOrder({
    required LocalSaleContext context,
    required String orderId,
    required String action,
  }) async {
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'commerce_order',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Order not found');
      final current =
          commerceOrderStatusFromValue(rows.single['status']! as String);
      if (action == 'complete') {
        throw StateError('Complete the order only after a finalized sale');
      }
      final next = nextCommerceOrderStatus(current, action);
      await txn.update(
        'commerce_order',
        {
          'status': commerceOrderStatusValue(next),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'commerce_order',
        'entity_id': orderId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'commerceOrderId': orderId,
          'event': action,
          'status': commerceOrderStatusValue(next),
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> completeCommerceOrder({
    required LocalSaleContext context,
    required String orderId,
    required String saleId,
  }) async {
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      final orders = await txn.query(
        'commerce_order',
        columns: ['status', 'sale_id'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orders.isEmpty) throw StateError('Order not found');
      final row = orders.single;
      if (row['sale_id'] != null) {
        if (row['sale_id'] == saleId) return;
        throw StateError('Order is already linked to another sale');
      }
      final current =
          commerceOrderStatusFromValue(row['status']! as String);
      final next = nextCommerceOrderStatus(current, 'complete');

      final sales = await txn.query(
        'sale',
        columns: ['id', 'status'],
        where: 'id = ? AND status = ?',
        whereArgs: [saleId, 'finalized'],
        limit: 1,
      );
      if (sales.isEmpty) {
        throw StateError('Finalized sale not found');
      }

      await txn.update(
        'commerce_order',
        {
          'status': commerceOrderStatusValue(next),
          'sale_id': saleId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'commerce_order',
        'entity_id': orderId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'commerceOrderId': orderId,
          'event': 'completed',
          'status': 'completed',
          'saleId': saleId,
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> _appendAuditEvent(
    DatabaseExecutor executor, {
    required LocalSaleContext context,
    required String action,
    required String entityType,
    required String entityId,
    required DateTime occurredAt,
    String outcome = 'success',
    Map<String, Object?> metadata = const {},
  }) async {
    final eventId = _uuid.v4();
    final idempotencyKey = 'audit:$eventId';
    await executor.insert('local_audit_event', {
      'id': eventId,
      'actor_user_id': context.userId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'outcome': outcome,
      'metadata_json': jsonEncode(metadata),
    });
    await executor.insert('sync_outbox', {
      'id': _uuid.v4(),
      'entity_type': 'audit_event',
      'entity_id': eventId,
      'organization_id': context.organizationId,
      'business_id': context.businessId,
      'store_id': context.storeId,
      'terminal_id': context.terminalId,
      'idempotency_key': idempotencyKey,
      'payload_json': jsonEncode({
        'auditEventId': eventId,
        'actorUserId': context.userId,
        'action': action,
        'affectedEntityType': entityType,
        'affectedEntityId': entityId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'outcome': outcome,
        'metadata': metadata,
      }),
      'state': 'pending',
      'created_at': occurredAt.toUtc().toIso8601String(),
    });
  }

  Future<bool> canReadAudit(LocalSaleContext context) async {
    final rows = await _database.query(
      'employee',
      columns: ['role'],
      where: 'id = ? AND active = 1',
      whereArgs: [context.userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final role = rows.single['role']! as String;
    return role == 'owner' || role == 'manager';
  }

  Future<List<LocalAuditEvent>> listAuditEvents({int limit = 200}) async {
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError('Audit limit must be between 1 and 1000');
    }
    final rows = await _database.query(
      'local_audit_event',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((row) {
      final decoded = jsonDecode(row['metadata_json']! as String);
      return LocalAuditEvent(
        id: row['id']! as String,
        actorUserId: row['actor_user_id']! as String,
        action: row['action']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        outcome: row['outcome']! as String,
        metadata: decoded is Map
            ? Map<String, Object?>.from(decoded)
            : const {},
      );
    }).toList();
  }

  Future<LoyaltyProgram> loyaltyProgram() async {
    final rows = await _database.query(
      'loyalty_program',
      where: 'singleton_id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return const LoyaltyProgram(
        enabled: false,
        pointsPer100Rupees: 1,
        redemptionMinorPerPoint: 100,
        maxRedemptionBps: 2000,
      );
    }
    final row = rows.single;
    return LoyaltyProgram(
      enabled: (row['enabled']! as int) == 1,
      pointsPer100Rupees: row['points_per_100_rupees']! as int,
      redemptionMinorPerPoint: row['redemption_minor_per_point']! as int,
      maxRedemptionBps: row['max_redemption_bps']! as int,
    );
  }

  Future<void> updateLoyaltyProgram({
    required LocalSaleContext context,
    required LoyaltyProgram program,
  }) async {
    validateLoyaltyProgram(program);
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      await txn.update(
        'loyalty_program',
        {
          'enabled': program.enabled ? 1 : 0,
          'points_per_100_rupees': program.pointsPer100Rupees,
          'redemption_minor_per_point': program.redemptionMinorPerPoint,
          'max_redemption_bps': program.maxRedemptionBps,
          'updated_at': now.toIso8601String(),
        },
        where: 'singleton_id = 1',
      );
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'loyalty_program',
        'entity_id': context.businessId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'businessId': context.businessId,
          'enabled': program.enabled,
          'pointsPer100Rupees': program.pointsPer100Rupees,
          'redemptionMinorPerPoint': program.redemptionMinorPerPoint,
          'maxRedemptionBps': program.maxRedemptionBps,
          'updatedAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<int> customerLoyaltyBalance(String customerId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN entry_type IN ('earn', 'adjustment_in') THEN points
            ELSE -points
          END
        ),
        0
      ) AS points
      FROM customer_loyalty_entry
      WHERE customer_id = ?
      ''',
      [customerId],
    );
    return rows.single['points']! as int;
  }

  Future<LocalPromotion> addPromotion({
    required LocalSaleContext context,
    required String name,
    required String type,
    required int value,
    required DateTime startsAt,
    required DateTime endsAt,
    List<String> productIds = const [],
    int minBasketMinor = 0,
    int? maxDiscountMinor,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        !{'percentage', 'fixed'}.contains(type) ||
        value <= 0 ||
        minBasketMinor < 0 ||
        (maxDiscountMinor != null && maxDiscountMinor < 0) ||
        !startsAt.isBefore(endsAt) ||
        (type == 'percentage' && value > 10000)) {
      throw ArgumentError('Invalid promotion');
    }
    final id = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      await txn.insert('promotion', {
        'id': id,
        'name': trimmed,
        'promotion_type': type,
        'value': value,
        'min_basket_minor': minBasketMinor,
        'max_discount_minor': maxDiscountMinor,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'active': 1,
      });
      for (final productId in productIds.toSet()) {
        await txn.insert('promotion_product', {
          'promotion_id': id,
          'product_id': productId,
        });
      }
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'promotion',
        'entity_id': id,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'promotionId': id,
          'name': trimmed,
          'type': type,
          'value': value,
          'minBasketMinor': minBasketMinor,
          'maxDiscountMinor': maxDiscountMinor,
          'startsAt': startsAt.toUtc().toIso8601String(),
          'endsAt': endsAt.toUtc().toIso8601String(),
          'productIds': productIds.toSet().toList(),
          'active': true,
        }),
        'state': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
    return LocalPromotion(
      id: id,
      name: trimmed,
      type: type,
      value: value,
      minBasketMinor: minBasketMinor,
      maxDiscountMinor: maxDiscountMinor,
      startsAt: startsAt.toUtc(),
      endsAt: endsAt.toUtc(),
      active: true,
      productIds: productIds.toSet().toList(),
    );
  }

  Future<List<LocalPromotion>> listPromotions({bool activeOnly = false}) async {
    final rows = await _database.query(
      'promotion',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'starts_at DESC, name COLLATE NOCASE',
    );
    final result = <LocalPromotion>[];
    for (final row in rows) {
      final id = row['id']! as String;
      final products = await _database.query(
        'promotion_product',
        columns: ['product_id'],
        where: 'promotion_id = ?',
        whereArgs: [id],
      );
      result.add(
        LocalPromotion(
          id: id,
          name: row['name']! as String,
          type: row['promotion_type']! as String,
          value: row['value']! as int,
          minBasketMinor: row['min_basket_minor']! as int,
          maxDiscountMinor: row['max_discount_minor'] as int?,
          startsAt: DateTime.parse(row['starts_at']! as String),
          endsAt: DateTime.parse(row['ends_at']! as String),
          active: (row['active']! as int) == 1,
          productIds: products
              .map((value) => value['product_id']! as String)
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<void> setPromotionActive({
    required LocalSaleContext context,
    required String promotionId,
    required bool active,
  }) async {
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      await txn.update(
        'promotion',
        {'active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [promotionId],
      );
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'promotion',
        'entity_id': promotionId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'promotionId': promotionId,
          'active': active,
          'updatedAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<PromotionEvaluation?> bestPromotionForLines(
    List<SaleLineInput> lines, {
    DateTime? now,
  }) async {
    final gross = <String, int>{};
    final existing = <String, int>{};
    for (final line in lines) {
      gross[line.product.id] =
          (line.product.unitPriceMinor * line.quantityMilli + 500) ~/ 1000;
      existing[line.product.id] = line.discountMinor;
    }
    return selectBestPromotion(
      promotions: await listPromotions(activeOnly: true),
      grossMinorByProduct: gross,
      existingDiscountMinorByProduct: existing,
      now: now ?? DateTime.now(),
    );
  }

  Future<LocalCustomer> addCustomer({
    required String name,
    String? mobile,
    CommunicationConsent consent = CommunicationConsent.unknown,
  }) async {
    final trimmedName = name.trim();
    final trimmedMobile = mobile?.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Customer name is required');
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database.insert('customer', {
      'id': id,
      'name': trimmedName,
      'mobile_e164':
          trimmedMobile == null || trimmedMobile.isEmpty ? null : trimmedMobile,
      'communication_consent': communicationConsentValue(consent),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return LocalCustomer(
      id: id,
      name: trimmedName,
      mobile: trimmedMobile == null || trimmedMobile.isEmpty
          ? null
          : trimmedMobile,
      creditBalanceMinor: 0,
      overdueMinor: 0,
      consent: consent,
    );
  }

  Future<List<CreditEntry>> customerCreditEntries(String customerId) async {
    final rows = await _database.query(
      'customer_credit_entry',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'occurred_at, id',
    );
    return rows
        .map(
          (row) => CreditEntry(
            id: row['id']! as String,
            customerId: row['customer_id']! as String,
            type: creditEntryTypeFromValue(row['entry_type']! as String),
            amountMinor: row['amount_minor']! as int,
            occurredAt: DateTime.parse(row['occurred_at']! as String),
            dueDate: row['due_date'] == null
                ? null
                : DateTime.parse(row['due_date']! as String),
            saleId: row['sale_id'] as String?,
          ),
        )
        .toList();
  }

  Future<List<LocalCustomer>> listCustomers({String query = ''}) async {
    final trimmed = query.trim();
    final rows = trimmed.isEmpty
        ? await _database.query('customer', orderBy: 'name COLLATE NOCASE')
        : await _database.query(
            'customer',
            where: 'name LIKE ? OR mobile_e164 LIKE ?',
            whereArgs: ['%$trimmed%', '%$trimmed%'],
            orderBy: 'name COLLATE NOCASE',
          );

    final result = <LocalCustomer>[];
    for (final row in rows) {
      final customerId = row['id']! as String;
      final entries = await customerCreditEntries(customerId);
      final summary = summarizeCredit(
        entries,
        asOf: DateTime.now().toUtc(),
      );
      final saleRows = await _database.rawQuery(
        'SELECT MAX(local_created_at) AS last_purchase FROM sale WHERE customer_id = ?',
        [customerId],
      );
      final lastPurchaseText = saleRows.single['last_purchase'] as String?;
      result.add(
        LocalCustomer(
          id: customerId,
          name: row['name']! as String,
          mobile: row['mobile_e164'] as String?,
          creditBalanceMinor: summary.balanceMinor,
          overdueMinor: summary.overdueMinor,
          lastPurchaseAt:
              lastPurchaseText == null ? null : DateTime.parse(lastPurchaseText),
          consent: communicationConsentFromValue(
            row['communication_consent']! as String,
          ),
          loyaltyPoints: await customerLoyaltyBalance(customerId),
        ),
      );
    }
    return result;
  }

  Future<void> collectCustomerCredit({
    required LocalSaleContext context,
    required String customerId,
    required int amountMinor,
    String collectionMethod = 'cash',
    String? note,
  }) {
    if (amountMinor <= 0) {
      throw ArgumentError('Collection amount must be positive');
    }
    if (!{'cash', 'upi', 'card'}.contains(collectionMethod)) {
      throw ArgumentError('Unsupported collection method');
    }

    return _database.transaction((txn) async {
      final balanceRows = await txn.rawQuery(
        '''
        SELECT COALESCE(
          SUM(
            CASE
              WHEN entry_type IN ('charge', 'correction_increase')
                THEN amount_minor
              ELSE -amount_minor
            END
          ),
          0
        ) AS balance_minor
        FROM customer_credit_entry
        WHERE customer_id = ?
        ''',
        [customerId],
      );
      final balance = balanceRows.single['balance_minor']! as int;
      if (amountMinor > balance) {
        throw StateError('Collection cannot exceed customer credit balance');
      }

      final entryId = _uuid.v4();
      final idempotencyKey = _uuid.v4();
      final now = DateTime.now().toUtc();
      final shiftId = collectionMethod == 'cash'
          ? await _openShiftId(txn)
          : null;
      await txn.insert('customer_credit_entry', {
        'id': entryId,
        'customer_id': customerId,
        'entry_type': 'payment',
        'amount_minor': amountMinor,
        'collection_method': collectionMethod,
        'shift_id': shiftId,
        'note': note?.trim(),
        'occurred_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'customer_credit_entry',
        'entity_id': entryId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'entryId': entryId,
          'customerId': customerId,
          'entryType': 'payment',
          'amountMinor': amountMinor,
          'collectionMethod': collectionMethod,
          'shiftId': shiftId,
          'note': note?.trim(),
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<int> customerCreditEntryCount(String customerId) async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM customer_credit_entry WHERE customer_id = ?',
      [customerId],
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  Future<LocalSupplier> addSupplier({
    required String name,
    String? mobile,
    String? gstin,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Supplier name is required');
    }
    final now = DateTime.now().toUtc();
    final supplier = LocalSupplier(
      id: _uuid.v4(),
      name: trimmedName,
      mobile: mobile?.trim().isEmpty ?? true ? null : mobile!.trim(),
      gstin: gstin?.trim().isEmpty ?? true ? null : gstin!.trim(),
      balanceMinor: 0,
    );
    await _database.insert('supplier', {
      'id': supplier.id,
      'name': supplier.name,
      'mobile_e164': supplier.mobile,
      'gstin': supplier.gstin,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return supplier;
  }

  Future<int> _supplierBalanceMinor(
    DatabaseExecutor executor,
    String supplierId,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN entry_type IN ('purchase_charge', 'correction_increase')
              THEN amount_minor
            ELSE -amount_minor
          END
        ),
        0
      ) AS balance_minor
      FROM supplier_ledger_entry
      WHERE supplier_id = ?
      ''',
      [supplierId],
    );
    return rows.single['balance_minor']! as int;
  }

  Future<List<LocalSupplier>> listSuppliers() async {
    final rows = await _database.query(
      'supplier',
      orderBy: 'name COLLATE NOCASE',
    );
    final result = <LocalSupplier>[];
    for (final row in rows) {
      final id = row['id']! as String;
      result.add(
        LocalSupplier(
          id: id,
          name: row['name']! as String,
          mobile: row['mobile_e164'] as String?,
          gstin: row['gstin'] as String?,
          balanceMinor: await _supplierBalanceMinor(_database, id),
        ),
      );
    }
    return result;
  }

  Future<String> createPurchaseOrder({
    required LocalSaleContext context,
    required String supplierId,
    required String productId,
    required int quantityMilli,
    required int unitCostMinor,
    int taxMinor = 0,
    String? note,
  }) async {
    final totalMinor = purchaseLineTotalMinor(
      quantityMilli: quantityMilli,
      unitCostMinor: unitCostMinor,
      taxMinor: taxMinor,
    );
    final orderId = _uuid.v4();
    final lineId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();
    final orderNumber = 'PO-${now.microsecondsSinceEpoch}';

    await _database.transaction((txn) async {
      final supplierRows = await txn.query(
        'supplier',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [supplierId],
        limit: 1,
      );
      final productRows = await txn.query(
        'product',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (supplierRows.isEmpty || productRows.isEmpty) {
        throw StateError('Supplier or product not found');
      }

      await txn.insert('purchase_order', {
        'id': orderId,
        'supplier_id': supplierId,
        'order_number': orderNumber,
        'status': 'ordered',
        'ordered_at': now.toIso8601String(),
        'note': note?.trim(),
      });
      await txn.insert('purchase_order_line', {
        'id': lineId,
        'purchase_order_id': orderId,
        'product_id': productId,
        'quantity_ordered_milli': quantityMilli,
        'quantity_received_milli': 0,
        'unit_cost_minor': unitCostMinor,
        'tax_minor': taxMinor,
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'purchase_order',
        'entity_id': orderId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'purchaseOrderId': orderId,
          'supplierId': supplierId,
          'orderNumber': orderNumber,
          'orderedAt': now.toIso8601String(),
          'note': note?.trim(),
          'totalMinor': totalMinor,
          'lines': [
            {
              'lineId': lineId,
              'productId': productId,
              'quantityOrderedMilli': quantityMilli,
              'unitCostMinor': unitCostMinor,
              'taxMinor': taxMinor,
            }
          ],
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
    return orderId;
  }

  Future<List<LocalPurchaseOrder>> listPurchaseOrders() async {
    final rows = await _database.rawQuery(
      '''
      SELECT po.*, s.name AS supplier_name
      FROM purchase_order po
      INNER JOIN supplier s ON s.id = po.supplier_id
      ORDER BY po.ordered_at DESC
      ''',
    );
    final result = <LocalPurchaseOrder>[];
    for (final row in rows) {
      final orderId = row['id']! as String;
      final lineRows = await _database.rawQuery(
        '''
        SELECT pol.*, p.name AS product_name
        FROM purchase_order_line pol
        INNER JOIN product p ON p.id = pol.product_id
        WHERE pol.purchase_order_id = ?
        ORDER BY pol.id
        ''',
        [orderId],
      );
      final lines = lineRows
          .map(
            (line) => LocalPurchaseOrderLine(
              id: line['id']! as String,
              productId: line['product_id']! as String,
              productName: line['product_name']! as String,
              quantityOrderedMilli:
                  line['quantity_ordered_milli']! as int,
              quantityReceivedMilli:
                  line['quantity_received_milli']! as int,
              unitCostMinor: line['unit_cost_minor']! as int,
              taxMinor: line['tax_minor']! as int,
            ),
          )
          .toList();
      result.add(
        LocalPurchaseOrder(
          id: orderId,
          supplierId: row['supplier_id']! as String,
          supplierName: row['supplier_name']! as String,
          orderNumber: row['order_number']! as String,
          status: row['status']! as String,
          orderedAt: DateTime.parse(row['ordered_at']! as String),
          totalMinor:
              lines.fold(0, (sum, line) => sum + line.lineTotalMinor),
          lines: lines,
        ),
      );
    }
    return result;
  }

  Future<String> receivePurchaseOrder({
    required LocalSaleContext context,
    required String purchaseOrderId,
    String? supplierInvoiceNumber,
  }) async {
    final receiptId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction((txn) async {
      final orderRows = await txn.query(
        'purchase_order',
        where: 'id = ?',
        whereArgs: [purchaseOrderId],
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw StateError('Purchase order not found');
      }
      final order = orderRows.single;
      final status = order['status']! as String;
      if (status == 'received' || status == 'cancelled') {
        throw StateError('Purchase order cannot be received');
      }

      final supplierId = order['supplier_id']! as String;
      final lineRows = await txn.query(
        'purchase_order_line',
        where: 'purchase_order_id = ?',
        whereArgs: [purchaseOrderId],
      );
      if (lineRows.isEmpty) {
        throw StateError('Purchase order has no lines');
      }

      final prepared = <Map<String, Object?>>[];
      var totalMinor = 0;
      for (final line in lineRows) {
        final orderedMilli = line['quantity_ordered_milli']! as int;
        final alreadyReceived = line['quantity_received_milli']! as int;
        final remainingMilli = orderedMilli - alreadyReceived;
        if (remainingMilli <= 0) continue;

        final unitCostMinor = line['unit_cost_minor']! as int;
        final taxMinor = line['tax_minor']! as int;
        final lineTotalMinor = purchaseLineTotalMinor(
          quantityMilli: remainingMilli,
          unitCostMinor: unitCostMinor,
          taxMinor: taxMinor,
        );
        totalMinor += lineTotalMinor;
        prepared.add({
          'purchase_order_line_id': line['id'],
          'product_id': line['product_id'],
          'quantity_received_milli': remainingMilli,
          'quantity_ordered_milli': orderedMilli,
          'unit_cost_minor': unitCostMinor,
          'tax_minor': taxMinor,
          'line_total_minor': lineTotalMinor,
        });
      }

      if (prepared.isEmpty || totalMinor <= 0) {
        throw StateError('Nothing remains to receive');
      }

      await txn.insert('purchase_receipt', {
        'id': receiptId,
        'supplier_id': supplierId,
        'purchase_order_id': purchaseOrderId,
        'supplier_invoice_number': supplierInvoiceNumber?.trim().isEmpty ?? true
            ? null
            : supplierInvoiceNumber!.trim(),
        'received_at': now.toIso8601String(),
        'total_minor': totalMinor,
        'idempotency_key': idempotencyKey,
      });

      final receivedLines = <Map<String, Object?>>[];
      for (final line in prepared) {
        final productId = line['product_id']! as String;
        final remainingMilli = line['quantity_received_milli']! as int;
        final orderedMilli = line['quantity_ordered_milli']! as int;

        await txn.insert('purchase_receipt_line', {
          'id': _uuid.v4(),
          'purchase_receipt_id': receiptId,
          'purchase_order_line_id': line['purchase_order_line_id'],
          'product_id': productId,
          'quantity_received_milli': remainingMilli,
          'unit_cost_minor': line['unit_cost_minor'],
          'tax_minor': line['tax_minor'],
          'line_total_minor': line['line_total_minor'],
        });

        await txn.update(
          'purchase_order_line',
          {'quantity_received_milli': orderedMilli},
          where: 'id = ?',
          whereArgs: [line['purchase_order_line_id']],
        );

        await txn.insert('stock_movement', {
          'id': _uuid.v4(),
          'product_id': productId,
          'movement_type': 'receive',
          'quantity_delta_milli': remainingMilli,
          'source_entity_type': 'purchase_receipt',
          'source_entity_id': receiptId,
          'occurred_at': now.toIso8601String(),
          'idempotency_key': 'purchase-receipt:$receiptId:$productId',
        });

        receivedLines.add({
          'productId': productId,
          'quantityReceivedMilli': remainingMilli,
          'unitCostMinor': line['unit_cost_minor'],
          'taxMinor': line['tax_minor'],
          'lineTotalMinor': line['line_total_minor'],
        });
      }

      await txn.insert('supplier_ledger_entry', {
        'id': _uuid.v4(),
        'supplier_id': supplierId,
        'entry_type': 'purchase_charge',
        'amount_minor': totalMinor,
        'source_id': receiptId,
        'occurred_at': now.toIso8601String(),
        'idempotency_key': 'supplier-charge:$receiptId',
      });

      await txn.update(
        'purchase_order',
        {'status': 'received'},
        where: 'id = ?',
        whereArgs: [purchaseOrderId],
      );

      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'purchase_receipt',
        'entity_id': receiptId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'purchaseReceiptId': receiptId,
          'purchaseOrderId': purchaseOrderId,
          'supplierId': supplierId,
          'supplierInvoiceNumber': supplierInvoiceNumber?.trim(),
          'receivedAt': now.toIso8601String(),
          'totalMinor': totalMinor,
          'lines': receivedLines,
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
    return receiptId;
  }

  Future<String> recordPurchaseReturn({
    required LocalSaleContext context,
    required String supplierId,
    required String productId,
    required int quantityMilli,
    required int creditMinor,
    required String reason,
    String? purchaseReceiptId,
  }) async {
    if (quantityMilli <= 0 || creditMinor <= 0 || reason.trim().isEmpty) {
      throw ArgumentError('Invalid purchase return');
    }
    final returnId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction((txn) async {
      final stockRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity_delta_milli), 0) AS on_hand_milli
        FROM stock_movement
        WHERE product_id = ?
        ''',
        [productId],
      );
      final onHand = stockRows.single['on_hand_milli']! as int;
      if (quantityMilli > onHand) {
        throw StateError('Purchase return exceeds available stock');
      }

      await txn.insert('purchase_return', {
        'id': returnId,
        'supplier_id': supplierId,
        'purchase_receipt_id': purchaseReceiptId,
        'product_id': productId,
        'quantity_returned_milli': quantityMilli,
        'credit_minor': creditMinor,
        'reason': reason.trim(),
        'returned_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });

      await txn.insert('stock_movement', {
        'id': _uuid.v4(),
        'product_id': productId,
        'movement_type': 'purchase_return',
        'quantity_delta_milli': -quantityMilli,
        'reason': reason.trim(),
        'source_entity_type': 'purchase_return',
        'source_entity_id': returnId,
        'occurred_at': now.toIso8601String(),
        'idempotency_key': 'purchase-return:$returnId:$productId',
      });

      await txn.insert('supplier_ledger_entry', {
        'id': _uuid.v4(),
        'supplier_id': supplierId,
        'entry_type': 'purchase_return_credit',
        'amount_minor': creditMinor,
        'source_id': returnId,
        'note': reason.trim(),
        'occurred_at': now.toIso8601String(),
        'idempotency_key': 'supplier-return:$returnId',
      });

      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'purchase_return',
        'entity_id': returnId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'purchaseReturnId': returnId,
          'supplierId': supplierId,
          'purchaseReceiptId': purchaseReceiptId,
          'productId': productId,
          'quantityReturnedMilli': quantityMilli,
          'creditMinor': creditMinor,
          'reason': reason.trim(),
          'returnedAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
    });
    return returnId;
  }

  Future<void> paySupplier({
    required LocalSaleContext context,
    required String supplierId,
    required int amountMinor,
    String paymentMethod = 'cash',
    String? note,
  }) {
    if (amountMinor <= 0) {
      throw ArgumentError('Supplier payment must be positive');
    }
    if (!{'cash', 'upi', 'card', 'bank'}.contains(paymentMethod)) {
      throw ArgumentError('Unsupported supplier payment method');
    }

    return _database.transaction((txn) async {
      final balance = await _supplierBalanceMinor(txn, supplierId);
      if (balance <= 0 || amountMinor > balance) {
        throw StateError('Supplier payment exceeds payable balance');
      }

      final entryId = _uuid.v4();
      final idempotencyKey = _uuid.v4();
      final now = DateTime.now().toUtc();
      await txn.insert('supplier_ledger_entry', {
        'id': entryId,
        'supplier_id': supplierId,
        'entry_type': 'payment',
        'amount_minor': amountMinor,
        'payment_method': paymentMethod,
        'note': note?.trim(),
        'occurred_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'supplier_ledger_entry',
        'entity_id': entryId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'entryId': entryId,
          'supplierId': supplierId,
          'entryType': 'payment',
          'amountMinor': amountMinor,
          'paymentMethod': paymentMethod,
          'note': note?.trim(),
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'supplier.paid',
        entityType: 'supplier_ledger_entry',
        entityId: entryId,
        occurredAt: now,
        metadata: {'supplierId': supplierId, 'amountMinor': amountMinor, 'paymentMethod': paymentMethod},
      );
    });
  }

  Future<List<SupplierLedgerEntry>> supplierLedgerEntries(
    String supplierId,
  ) async {
    final rows = await _database.query(
      'supplier_ledger_entry',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'occurred_at, id',
    );
    return rows
        .map(
          (row) => SupplierLedgerEntry(
            id: row['id']! as String,
            type: row['entry_type']! as String,
            amountMinor: row['amount_minor']! as int,
            occurredAt: DateTime.parse(row['occurred_at']! as String),
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<String?> _openShiftId(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'shift',
      columns: ['id'],
      where: "status = 'open'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id']! as String;
  }

  Future<LocalEmployee> addEmployee({
    required LocalSaleContext context,
    required String name,
    required EmployeeRole role,
    String? mobile,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Employee name is required');
    }
    final employee = LocalEmployee(
      id: _uuid.v4(),
      name: trimmed,
      mobile: mobile?.trim().isEmpty ?? true ? null : mobile!.trim(),
      role: role,
      active: true,
    );
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      await txn.insert('employee', {
        'id': employee.id,
        'name': employee.name,
        'mobile_e164': employee.mobile,
        'role': employeeRoleValue(employee.role),
        'active': 1,
        'created_at': now.toIso8601String(),
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'employee',
        'entity_id': employee.id,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'employeeId': employee.id,
          'name': employee.name,
          'mobile': employee.mobile,
          'role': employeeRoleValue(employee.role),
          'active': true,
          'createdAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'employee.created',
        entityType: 'employee',
        entityId: employee.id,
        occurredAt: now,
        metadata: {'reference': employee.name, 'role': employeeRoleValue(employee.role)},
      );
    });
    return employee;
  }

  Future<List<LocalEmployee>> listEmployees() async {
    final rows = await _database.query(
      'employee',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => LocalEmployee(
            id: row['id']! as String,
            name: row['name']! as String,
            mobile: row['mobile_e164'] as String?,
            role: employeeRoleFromValue(row['role']! as String),
            active: (row['active']! as int) == 1,
          ),
        )
        .toList();
  }

  Future<LocalShift> openShift({
    required LocalSaleContext context,
    required String employeeId,
    required int openingCashMinor,
  }) async {
    if (openingCashMinor < 0) {
      throw ArgumentError('Opening cash cannot be negative');
    }
    final shiftId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    late String employeeName;

    await _database.transaction((txn) async {
      if (await _openShiftId(txn) != null) {
        throw StateError('A shift is already open');
      }
      final employees = await txn.query(
        'employee',
        where: 'id = ? AND active = 1',
        whereArgs: [employeeId],
        limit: 1,
      );
      if (employees.isEmpty) {
        throw StateError('Active employee not found');
      }
      employeeName = employees.single['name']! as String;

      await txn.insert('shift', {
        'id': shiftId,
        'employee_id': employeeId,
        'opened_at': now.toIso8601String(),
        'opening_cash_minor': openingCashMinor,
        'status': 'open',
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'shift',
        'entity_id': shiftId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'shiftId': shiftId,
          'employeeId': employeeId,
          'event': 'opened',
          'openingCashMinor': openingCashMinor,
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'shift.opened',
        entityType: 'shift',
        entityId: shiftId,
        occurredAt: now,
        metadata: {'reference': employeeName, 'openingCashMinor': openingCashMinor},
      );
    });

    return LocalShift(
      id: shiftId,
      employeeId: employeeId,
      employeeName: employeeName,
      openedAt: now,
      openingCashMinor: openingCashMinor,
      status: 'open',
    );
  }

  Future<LocalShift?> currentShift() async {
    final rows = await _database.rawQuery(
      '''
      SELECT sh.*, e.name AS employee_name
      FROM shift sh
      INNER JOIN employee e ON e.id = sh.employee_id
      WHERE sh.status = 'open'
      ORDER BY sh.opened_at DESC
      LIMIT 1
      ''',
    );
    if (rows.isEmpty) return null;
    return _shiftFromRow(rows.single);
  }

  LocalShift _shiftFromRow(Map<String, Object?> row) {
    return LocalShift(
      id: row['id']! as String,
      employeeId: row['employee_id']! as String,
      employeeName: row['employee_name']! as String,
      openedAt: DateTime.parse(row['opened_at']! as String),
      openingCashMinor: row['opening_cash_minor']! as int,
      status: row['status']! as String,
      closedAt: row['closed_at'] == null
          ? null
          : DateTime.parse(row['closed_at']! as String),
      expectedClosingCashMinor: row['expected_closing_cash_minor'] as int?,
      actualClosingCashMinor: row['actual_closing_cash_minor'] as int?,
      varianceMinor: row['variance_minor'] as int?,
    );
  }

  Future<List<LocalShift>> listShifts() async {
    final rows = await _database.rawQuery(
      '''
      SELECT sh.*, e.name AS employee_name
      FROM shift sh
      INNER JOIN employee e ON e.id = sh.employee_id
      ORDER BY sh.opened_at DESC
      ''',
    );
    return rows.map(_shiftFromRow).toList();
  }

  Future<void> recordCashMovement({
    required LocalSaleContext context,
    required String movementType,
    required int amountMinor,
    required String reason,
  }) async {
    if (!{'deposit', 'withdrawal'}.contains(movementType) ||
        amountMinor <= 0 ||
        reason.trim().isEmpty) {
      throw ArgumentError('Invalid cash movement');
    }
    final now = DateTime.now().toUtc();
    final idempotencyKey = _uuid.v4();
    await _database.transaction((txn) async {
      final shiftId = await _openShiftId(txn);
      if (shiftId == null) {
        throw StateError('Open a shift before changing drawer cash');
      }
      final movementId = _uuid.v4();
      await txn.insert('cash_movement', {
        'id': movementId,
        'shift_id': shiftId,
        'movement_type': movementType,
        'amount_minor': amountMinor,
        'reason': reason.trim(),
        'occurred_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'cash_movement',
        'entity_id': movementId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'cashMovementId': movementId,
          'shiftId': shiftId,
          'movementType': movementType,
          'amountMinor': amountMinor,
          'reason': reason.trim(),
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'cash.movement',
        entityType: 'cash_movement',
        entityId: movementId,
        occurredAt: now,
        metadata: {'movementType': movementType, 'amountMinor': amountMinor},
      );
    });
  }

  Future<LocalExpense> addExpense({
    required LocalSaleContext context,
    required String category,
    required int amountMinor,
    String paymentMethod = 'cash',
    String? note,
  }) async {
    if (category.trim().isEmpty ||
        amountMinor <= 0 ||
        !{'cash', 'upi', 'card', 'bank'}.contains(paymentMethod)) {
      throw ArgumentError('Invalid expense');
    }
    final now = DateTime.now().toUtc();
    final expenseId = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    await _database.transaction((txn) async {
      final shiftId = await _openShiftId(txn);
      if (paymentMethod == 'cash' && shiftId == null) {
        throw StateError('Open a shift before recording a cash expense');
      }
      await txn.insert('expense', {
        'id': expenseId,
        'shift_id': shiftId,
        'category': category.trim(),
        'amount_minor': amountMinor,
        'payment_method': paymentMethod,
        'note': note?.trim(),
        'occurred_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'expense',
        'entity_id': expenseId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'expenseId': expenseId,
          'shiftId': shiftId,
          'category': category.trim(),
          'amountMinor': amountMinor,
          'paymentMethod': paymentMethod,
          'note': note?.trim(),
          'occurredAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'expense.recorded',
        entityType: 'expense',
        entityId: expenseId,
        occurredAt: now,
        metadata: {'reference': category.trim(), 'amountMinor': amountMinor, 'paymentMethod': paymentMethod},
      );
    });

    return LocalExpense(
      id: expenseId,
      category: category.trim(),
      amountMinor: amountMinor,
      paymentMethod: paymentMethod,
      occurredAt: now,
      note: note?.trim(),
    );
  }

  Future<List<LocalExpense>> listExpenses() async {
    final rows = await _database.query('expense', orderBy: 'occurred_at DESC');
    return rows
        .map(
          (row) => LocalExpense(
            id: row['id']! as String,
            category: row['category']! as String,
            amountMinor: row['amount_minor']! as int,
            paymentMethod: row['payment_method']! as String,
            occurredAt: DateTime.parse(row['occurred_at']! as String),
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<LocalShift> closeShift({
    required LocalSaleContext context,
    required int actualClosingCashMinor,
    int varianceApprovalThresholdMinor = 50000,
  }) async {
    if (actualClosingCashMinor < 0 || varianceApprovalThresholdMinor < 0) {
      throw ArgumentError('Invalid closing cash');
    }
    final now = DateTime.now().toUtc();
    late LocalShift closed;

    await _database.transaction((txn) async {
      final shiftRows = await txn.rawQuery(
        '''
        SELECT sh.*, e.name AS employee_name
        FROM shift sh
        INNER JOIN employee e ON e.id = sh.employee_id
        WHERE sh.status = 'open'
        LIMIT 1
        ''',
      );
      if (shiftRows.isEmpty) {
        throw StateError('No open shift');
      }
      final row = shiftRows.single;
      final shiftId = row['id']! as String;

      final cashSalesRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(p.amount_minor), 0) AS total
        FROM payment p
        INNER JOIN sale s ON s.id = p.sale_id
        WHERE s.shift_id = ? AND p.method = 'cash'
        ''',
        [shiftId],
      );
      final creditRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_minor), 0) AS total
        FROM customer_credit_entry
        WHERE shift_id = ? AND entry_type = 'payment'
          AND collection_method = 'cash'
        ''',
        [shiftId],
      );
      final movementRows = await txn.rawQuery(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN movement_type = 'deposit' THEN amount_minor ELSE 0 END), 0)
            AS deposits,
          COALESCE(SUM(CASE WHEN movement_type = 'withdrawal' THEN amount_minor ELSE 0 END), 0)
            AS withdrawals
        FROM cash_movement
        WHERE shift_id = ?
        ''',
        [shiftId],
      );
      final expenseRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_minor), 0) AS total
        FROM expense
        WHERE shift_id = ? AND payment_method = 'cash'
        ''',
        [shiftId],
      );
      final refundRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_minor), 0) AS total
        FROM refund
        WHERE shift_id = ? AND method = 'cash' AND status = 'captured'
        ''',
        [shiftId],
      );

      final expected = expectedClosingCashMinor(
        openingCashMinor: row['opening_cash_minor']! as int,
        cashSalesMinor: cashSalesRows.single['total']! as int,
        cashCreditCollectionsMinor: creditRows.single['total']! as int,
        cashDepositsMinor: movementRows.single['deposits']! as int,
        cashWithdrawalsMinor:
            (movementRows.single['withdrawals']! as int) +
            (refundRows.single['total']! as int),
        cashExpensesMinor: expenseRows.single['total']! as int,
      );
      final variance = actualClosingCashMinor - expected;

      await txn.update(
        'shift',
        {
          'closed_at': now.toIso8601String(),
          'expected_closing_cash_minor': expected,
          'actual_closing_cash_minor': actualClosingCashMinor,
          'variance_minor': variance,
          'status': 'closed',
        },
        where: 'id = ?',
        whereArgs: [shiftId],
      );

      if (variance.abs() > varianceApprovalThresholdMinor) {
        await txn.insert('approval_request', {
          'id': _uuid.v4(),
          'action_type': 'cash_variance',
          'entity_type': 'shift',
          'entity_id': shiftId,
          'requested_by_employee_id': row['employee_id'],
          'requested_at': now.toIso8601String(),
          'status': 'pending',
          'reason': 'Cash variance requires review',
        });
      }

      final idempotencyKey = _uuid.v4();
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'shift',
        'entity_id': shiftId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'shiftId': shiftId,
          'event': 'closed',
          'expectedClosingCashMinor': expected,
          'actualClosingCashMinor': actualClosingCashMinor,
          'varianceMinor': variance,
          'closedAt': now.toIso8601String(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'shift.closed',
        entityType: 'shift',
        entityId: shiftId,
        occurredAt: now,
        metadata: {'expectedCashMinor': expected, 'actualCashMinor': actualClosingCashMinor, 'varianceMinor': variance},
      );

      closed = LocalShift(
        id: shiftId,
        employeeId: row['employee_id']! as String,
        employeeName: row['employee_name']! as String,
        openedAt: DateTime.parse(row['opened_at']! as String),
        openingCashMinor: row['opening_cash_minor']! as int,
        status: 'closed',
        closedAt: now,
        expectedClosingCashMinor: expected,
        actualClosingCashMinor: actualClosingCashMinor,
        varianceMinor: variance,
      );
    });
    return closed;
  }

  Future<bool> canResolveApprovals(LocalSaleContext context) async {
    final rows = await _database.query(
      'employee',
      columns: ['role'],
      where: 'id = ? AND active = 1',
      whereArgs: [context.userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final role = rows.single['role']! as String;
    return role == 'owner' || role == 'manager';
  }

  Future<String> requestApproval({
    required LocalSaleContext context,
    required String actionType,
    required String entityType,
    required String entityId,
    required String reason,
    String? actionFingerprint,
    int? requestedAmountMinor,
    Duration validFor = const Duration(hours: 2),
  }) async {
    final normalizedAction = actionType.trim();
    final normalizedEntityType = entityType.trim();
    final normalizedEntityId = entityId.trim();
    final normalizedReason = reason.trim();
    final normalizedFingerprint = actionFingerprint?.trim();

    if (normalizedAction.isEmpty ||
        normalizedEntityType.isEmpty ||
        normalizedEntityId.isEmpty ||
        normalizedReason.isEmpty ||
        (normalizedFingerprint != null && normalizedFingerprint.isEmpty) ||
        (requestedAmountMinor != null && requestedAmountMinor < 0) ||
        validFor <= Duration.zero ||
        validFor > const Duration(hours: 24)) {
      throw ArgumentError('Invalid approval request');
    }

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(validFor);

    return _database.transaction((txn) async {
      final requester = await txn.query(
        'employee',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [context.userId],
        limit: 1,
      );
      if (requester.isEmpty) {
        throw StateError('Active requester identity not found');
      }

      if (normalizedFingerprint != null) {
        final existing = await txn.query(
          'approval_request',
          columns: ['id'],
          where:
              'status = ? AND action_type = ? AND entity_type = ? '
              'AND entity_id = ? AND requested_by_employee_id = ? '
              'AND action_fingerprint = ?',
          whereArgs: [
            'pending',
            normalizedAction,
            normalizedEntityType,
            normalizedEntityId,
            context.userId,
            normalizedFingerprint,
          ],
          orderBy: 'requested_at DESC',
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return existing.single['id']! as String;
        }
      }

      final approvalId = _uuid.v4();
      await txn.insert('approval_request', {
        'id': approvalId,
        'action_type': normalizedAction,
        'entity_type': normalizedEntityType,
        'entity_id': normalizedEntityId,
        'requested_by_employee_id': context.userId,
        'requested_at': now.toIso8601String(),
        'status': 'pending',
        'reason': normalizedReason,
        'action_fingerprint': normalizedFingerprint,
        'requested_amount_minor': requestedAmountMinor,
        'expires_at': expiresAt.toIso8601String(),
      });

      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'approval_request',
        'entity_id': approvalId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': 'approval-request:$approvalId',
        'payload_json': jsonEncode({
          'approvalRequestId': approvalId,
          'actionType': normalizedAction,
          'entityType': normalizedEntityType,
          'entityId': normalizedEntityId,
          'requestedByUserId': context.userId,
          'requestedAt': now.toIso8601String(),
          'status': 'pending',
          'actionFingerprint': normalizedFingerprint,
          'requestedAmountMinor': requestedAmountMinor,
          'expiresAt': expiresAt.toIso8601String(),
          'reason': normalizedReason,
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });

      await _appendAuditEvent(
        txn,
        context: context,
        action: 'approval.requested',
        entityType: 'approval_request',
        entityId: approvalId,
        occurredAt: now,
        metadata: {
          'actionType': normalizedAction,
          'targetEntityType': normalizedEntityType,
          'targetEntityId': normalizedEntityId,
          'requestedAmountMinor': requestedAmountMinor,
        },
      );
      return approvalId;
    });
  }

  Future<List<LocalApprovalRequest>> listApprovalRequests({
    required LocalSaleContext context,
    LocalApprovalStatus? status,
    int limit = 100,
  }) async {
    if (limit <= 0 || limit > 500) {
      throw ArgumentError('Approval limit must be between 1 and 500');
    }
    if (!await canResolveApprovals(context)) {
      throw StateError('This role cannot review approvals');
    }

    final statusWhere = status == null ? '' : 'WHERE ar.status = ?';
    final args = status == null
        ? <Object?>[]
        : <Object?>[localApprovalStatusValue(status)];

    final rows = await _database.rawQuery(
      '''
      SELECT
        ar.*,
        requester.name AS requested_by_name,
        resolver.name AS resolved_by_name,
        ac.consumed_at
      FROM approval_request ar
      INNER JOIN employee requester
        ON requester.id = ar.requested_by_employee_id
      LEFT JOIN employee resolver
        ON resolver.id = ar.resolved_by_employee_id
      LEFT JOIN approval_consumption ac
        ON ac.approval_request_id = ar.id
      $statusWhere
      ORDER BY ar.requested_at DESC, ar.id DESC
      LIMIT ?
      ''',
      [...args, limit],
    );

    return rows
        .map(
          (row) => LocalApprovalRequest(
            id: row['id']! as String,
            actionType: row['action_type']! as String,
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            requestedByEmployeeId:
                row['requested_by_employee_id']! as String,
            requestedByName: row['requested_by_name']! as String,
            requestedAt: DateTime.parse(row['requested_at']! as String),
            status:
                localApprovalStatusFromValue(row['status']! as String),
            actionFingerprint: row['action_fingerprint'] as String?,
            requestedAmountMinor: row['requested_amount_minor'] as int?,
            expiresAt: row['expires_at'] == null
                ? null
                : DateTime.parse(row['expires_at']! as String),
            resolvedByEmployeeId:
                row['resolved_by_employee_id'] as String?,
            resolvedByName: row['resolved_by_name'] as String?,
            resolvedAt: row['resolved_at'] == null
                ? null
                : DateTime.parse(row['resolved_at']! as String),
            reason: row['reason'] as String?,
            consumed: row['consumed_at'] != null,
            consumedAt: row['consumed_at'] == null
                ? null
                : DateTime.parse(row['consumed_at']! as String),
          ),
        )
        .toList();
  }

  Future<void> resolveApprovalRequest({
    required LocalSaleContext context,
    required String approvalRequestId,
    required bool approve,
    String? reason,
  }) async {
    final normalizedId = approvalRequestId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('approvalRequestId is required');
    }
    final now = DateTime.now().toUtc();

    await _database.transaction((txn) async {
      final resolvers = await txn.query(
        'employee',
        columns: ['role'],
        where: 'id = ? AND active = 1',
        whereArgs: [context.userId],
        limit: 1,
      );
      if (resolvers.isEmpty) {
        throw StateError('Active resolver identity not found');
      }
      final role = resolvers.single['role']! as String;
      if (role != 'owner' && role != 'manager') {
        throw StateError('This role cannot resolve approvals');
      }

      final approvals = await txn.query(
        'approval_request',
        where: 'id = ?',
        whereArgs: [normalizedId],
        limit: 1,
      );
      if (approvals.isEmpty) {
        throw StateError('Approval request not found');
      }
      final approval = approvals.single;
      if (approval['status'] != 'pending') {
        throw StateError('Approval request is already resolved');
      }
      if (approval['requested_by_employee_id'] == context.userId) {
        throw StateError('You cannot resolve your own approval request');
      }

      final expiresAt = approval['expires_at'] as String?;
      if (approve &&
          expiresAt != null &&
          !now.isBefore(DateTime.parse(expiresAt).toUtc())) {
        throw StateError('Approval request has expired');
      }

      final status = approve ? 'approved' : 'rejected';
      await txn.update(
        'approval_request',
        {
          'status': status,
          'resolved_by_employee_id': context.userId,
          'resolved_at': now.toIso8601String(),
          if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [normalizedId, 'pending'],
      );

      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'approval_request',
        'entity_id': normalizedId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': 'approval-resolution:$normalizedId:$status',
        'payload_json': jsonEncode({
          'approvalRequestId': normalizedId,
          'status': status,
          'resolvedByUserId': context.userId,
          'resolvedAt': now.toIso8601String(),
          'reason': reason?.trim(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });

      await _appendAuditEvent(
        txn,
        context: context,
        action: approve ? 'approval.approved' : 'approval.rejected',
        entityType: 'approval_request',
        entityId: normalizedId,
        occurredAt: now,
        metadata: {
          'actionType': approval['action_type'],
          'targetEntityType': approval['entity_type'],
          'targetEntityId': approval['entity_id'],
        },
      );
    });
  }

  Future<String> _consumeApproval(
    DatabaseExecutor executor, {
    required LocalSaleContext context,
    required String actionType,
    required String entityType,
    required String entityId,
    required String actionFingerprint,
    required DateTime now,
  }) async {
    final rows = await executor.rawQuery(
      '''
      SELECT ar.id
      FROM approval_request ar
      LEFT JOIN approval_consumption ac
        ON ac.approval_request_id = ar.id
      WHERE ar.status = 'approved'
        AND ar.action_type = ?
        AND ar.entity_type = ?
        AND ar.entity_id = ?
        AND ar.requested_by_employee_id = ?
        AND ar.action_fingerprint = ?
        AND (ar.expires_at IS NULL OR ar.expires_at > ?)
        AND ac.id IS NULL
      ORDER BY ar.resolved_at DESC, ar.id DESC
      LIMIT 1
      ''',
      [
        actionType,
        entityType,
        entityId,
        context.userId,
        actionFingerprint,
        now.toIso8601String(),
      ],
    );
    if (rows.isEmpty) {
      throw StateError('Manager approval is required for this action');
    }

    final approvalId = rows.single['id']! as String;
    final consumptionId = _uuid.v4();
    final requestId = _uuid.v4();
    await executor.insert('approval_consumption', {
      'id': consumptionId,
      'approval_request_id': approvalId,
      'consumed_by_employee_id': context.userId,
      'action_fingerprint': actionFingerprint,
      'consumed_at': now.toIso8601String(),
      'request_id': requestId,
    });

    await executor.insert('sync_outbox', {
      'id': _uuid.v4(),
      'entity_type': 'approval_consumption',
      'entity_id': consumptionId,
      'organization_id': context.organizationId,
      'business_id': context.businessId,
      'store_id': context.storeId,
      'terminal_id': context.terminalId,
      'idempotency_key': 'approval-consumption:$approvalId',
      'payload_json': jsonEncode({
        'approvalConsumptionId': consumptionId,
        'approvalRequestId': approvalId,
        'consumedByUserId': context.userId,
        'actionFingerprint': actionFingerprint,
        'consumedAt': now.toIso8601String(),
        'requestId': requestId,
      }),
      'state': 'pending',
      'created_at': now.toIso8601String(),
    });

    await _appendAuditEvent(
      executor,
      context: context,
      action: 'approval.consumed',
      entityType: 'approval_request',
      entityId: approvalId,
      occurredAt: now,
      metadata: {
        'actionType': actionType,
        'targetEntityType': entityType,
        'targetEntityId': entityId,
      },
    );
    return approvalId;
  }

  Future<int> pendingApprovalCount() async {
    final rows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM approval_request WHERE status = 'pending'",
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  Future<List<AccountingExportRow>> accountingExportRows(
    ReportPeriod period, {
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final range = periodRange(period, reference);
    final start = range.start.toUtc().toIso8601String();
    final end = range.end.toUtc().toIso8601String();
    final rows = <AccountingExportRow>[];

    final sales = await _database.rawQuery(
      '''
      SELECT
        s.id,
        s.invoice_number,
        s.local_created_at,
        s.status,
        c.name AS party_name,
        p.method AS payment_method,
        COALESCE(SUM(sl.gross_minor), 0) AS gross_minor,
        COALESCE(SUM(sl.discount_minor), 0) AS discount_minor,
        COALESCE(SUM(sl.taxable_minor), 0) AS taxable_minor,
        COALESCE(SUM(sl.cgst_minor), 0) AS cgst_minor,
        COALESCE(SUM(sl.sgst_minor), 0) AS sgst_minor,
        COALESCE(SUM(sl.igst_minor), 0) AS igst_minor,
        COALESCE(SUM(sl.total_minor), 0) AS total_minor
      FROM sale s
      INNER JOIN sale_line sl ON sl.sale_id = s.id
      LEFT JOIN customer c ON c.id = s.customer_id
      LEFT JOIN payment p ON p.sale_id = s.id
      WHERE s.status = 'finalized'
        AND s.local_created_at >= ?
        AND s.local_created_at < ?
      GROUP BY
        s.id,
        s.invoice_number,
        s.local_created_at,
        s.status,
        c.name,
        p.method
      ORDER BY s.local_created_at
      ''',
      [start, end],
    );
    for (final row in sales) {
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.sales,
          sourceId: row['id']! as String,
          documentNumber: row['invoice_number']! as String,
          occurredAt: DateTime.parse(row['local_created_at']! as String),
          partyName: row['party_name'] as String?,
          description: 'Retail sale',
          balanceEffect: 'increase',
          grossMinor: row['gross_minor']! as int,
          discountMinor: row['discount_minor']! as int,
          tax: AccountingTaxBreakdown(
            taxableMinor: row['taxable_minor']! as int,
            cgstMinor: row['cgst_minor']! as int,
            sgstMinor: row['sgst_minor']! as int,
            igstMinor: row['igst_minor']! as int,
            unclassifiedTaxMinor: 0,
          ),
          totalMinor: row['total_minor']! as int,
          paymentMethod: row['payment_method'] as String?,
          status: row['status']! as String,
        ),
      );
    }

    final returns = await _database.rawQuery(
      '''
      SELECT
        sr.id,
        sr.return_number,
        sr.returned_at,
        sr.status,
        s.invoice_number,
        c.name AS party_name,
        COALESCE(SUM(srl.taxable_minor), 0) AS taxable_minor,
        COALESCE(SUM(srl.cgst_minor), 0) AS cgst_minor,
        COALESCE(SUM(srl.sgst_minor), 0) AS sgst_minor,
        COALESCE(SUM(srl.igst_minor), 0) AS igst_minor,
        COALESCE(SUM(srl.total_minor), 0) AS total_minor
      FROM sale_return sr
      INNER JOIN sale_return_line srl ON srl.sale_return_id = sr.id
      INNER JOIN sale s ON s.id = sr.sale_id
      LEFT JOIN customer c ON c.id = s.customer_id
      WHERE sr.status = 'finalized'
        AND sr.returned_at >= ?
        AND sr.returned_at < ?
      GROUP BY
        sr.id,
        sr.return_number,
        sr.returned_at,
        sr.status,
        s.invoice_number,
        c.name
      ORDER BY sr.returned_at
      ''',
      [start, end],
    );
    for (final row in returns) {
      final total = row['total_minor']! as int;
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.returns,
          sourceId: row['id']! as String,
          documentNumber: row['return_number']! as String,
          occurredAt: DateTime.parse(row['returned_at']! as String),
          partyName: row['party_name'] as String?,
          description: 'Return against ${row['invoice_number']}',
          balanceEffect: 'decrease',
          grossMinor: total,
          discountMinor: 0,
          tax: AccountingTaxBreakdown(
            taxableMinor: row['taxable_minor']! as int,
            cgstMinor: row['cgst_minor']! as int,
            sgstMinor: row['sgst_minor']! as int,
            igstMinor: row['igst_minor']! as int,
            unclassifiedTaxMinor: 0,
          ),
          totalMinor: total,
          status: row['status']! as String,
        ),
      );
    }

    final purchases = await _database.rawQuery(
      '''
      SELECT
        pr.id,
        pr.supplier_invoice_number,
        pr.received_at,
        sp.name AS party_name,
        COALESCE(SUM(prl.line_total_minor), 0) AS total_minor,
        COALESCE(SUM(prl.tax_minor), 0) AS tax_minor
      FROM purchase_receipt pr
      INNER JOIN purchase_receipt_line prl
        ON prl.purchase_receipt_id = pr.id
      INNER JOIN supplier sp ON sp.id = pr.supplier_id
      WHERE pr.received_at >= ?
        AND pr.received_at < ?
      GROUP BY
        pr.id,
        pr.supplier_invoice_number,
        pr.received_at,
        sp.name
      ORDER BY pr.received_at
      ''',
      [start, end],
    );
    for (final row in purchases) {
      final total = row['total_minor']! as int;
      final tax = row['tax_minor']! as int;
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.purchases,
          sourceId: row['id']! as String,
          documentNumber: row['supplier_invoice_number'] as String?,
          occurredAt: DateTime.parse(row['received_at']! as String),
          partyName: row['party_name']! as String,
          description: 'Purchase receipt',
          balanceEffect: 'increase',
          grossMinor: total,
          discountMinor: 0,
          tax: AccountingTaxBreakdown(
            taxableMinor: total - tax,
            cgstMinor: 0,
            sgstMinor: 0,
            igstMinor: 0,
            unclassifiedTaxMinor: tax,
          ),
          totalMinor: total,
          status: 'received',
        ),
      );
    }

    final expenses = await _database.rawQuery(
      '''
      SELECT *
      FROM expense
      WHERE occurred_at >= ? AND occurred_at < ?
      ORDER BY occurred_at
      ''',
      [start, end],
    );
    for (final row in expenses) {
      final amount = row['amount_minor']! as int;
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.expenses,
          sourceId: row['id']! as String,
          occurredAt: DateTime.parse(row['occurred_at']! as String),
          description: row['note'] == null
              ? row['category']! as String
              : '${row['category']} • ${row['note']}',
          balanceEffect: 'increase',
          grossMinor: amount,
          discountMinor: 0,
          tax: const AccountingTaxBreakdown(
            taxableMinor: 0,
            cgstMinor: 0,
            sgstMinor: 0,
            igstMinor: 0,
            unclassifiedTaxMinor: 0,
          ),
          totalMinor: amount,
          paymentMethod: row['payment_method']! as String,
          status: 'recorded',
        ),
      );
    }

    final credit = await _database.rawQuery(
      '''
      SELECT
        ce.*,
        c.name AS party_name,
        s.invoice_number
      FROM customer_credit_entry ce
      INNER JOIN customer c ON c.id = ce.customer_id
      LEFT JOIN sale s ON s.id = ce.sale_id
      WHERE ce.occurred_at >= ?
        AND ce.occurred_at < ?
      ORDER BY ce.occurred_at
      ''',
      [start, end],
    );
    for (final row in credit) {
      final amount = row['amount_minor']! as int;
      final type = row['entry_type']! as String;
      final increase = type == 'charge' || type == 'correction_increase';
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.customerCredit,
          sourceId: row['id']! as String,
          documentNumber: row['invoice_number'] as String?,
          occurredAt: DateTime.parse(row['occurred_at']! as String),
          partyName: row['party_name']! as String,
          description: row['note'] as String? ?? 'Customer credit $type',
          balanceEffect: increase ? 'increase' : 'decrease',
          grossMinor: amount,
          discountMinor: 0,
          tax: const AccountingTaxBreakdown(
            taxableMinor: 0,
            cgstMinor: 0,
            sgstMinor: 0,
            igstMinor: 0,
            unclassifiedTaxMinor: 0,
          ),
          totalMinor: amount,
          paymentMethod: row['collection_method'] as String?,
          status: type,
        ),
      );
    }

    final supplierLedger = await _database.rawQuery(
      '''
      SELECT
        le.*,
        sp.name AS party_name
      FROM supplier_ledger_entry le
      INNER JOIN supplier sp ON sp.id = le.supplier_id
      WHERE le.occurred_at >= ?
        AND le.occurred_at < ?
      ORDER BY le.occurred_at
      ''',
      [start, end],
    );
    for (final row in supplierLedger) {
      final amount = row['amount_minor']! as int;
      final type = row['entry_type']! as String;
      final increase =
          type == 'purchase_charge' || type == 'correction_increase';
      rows.add(
        AccountingExportRow(
          kind: AccountingRegisterKind.supplierLedger,
          sourceId: row['id']! as String,
          occurredAt: DateTime.parse(row['occurred_at']! as String),
          partyName: row['party_name']! as String,
          description: row['note'] as String? ?? 'Supplier ledger $type',
          balanceEffect: increase ? 'increase' : 'decrease',
          grossMinor: amount,
          discountMinor: 0,
          tax: const AccountingTaxBreakdown(
            taxableMinor: 0,
            cgstMinor: 0,
            sgstMinor: 0,
            igstMinor: 0,
            unclassifiedTaxMinor: 0,
          ),
          totalMinor: amount,
          paymentMethod: row['payment_method'] as String?,
          status: type,
        ),
      );
    }

    rows.sort((a, b) {
      final time = a.occurredAt.compareTo(b.occurredAt);
      if (time != 0) return time;
      final kind = accountingRegisterValue(a.kind)
          .compareTo(accountingRegisterValue(b.kind));
      if (kind != 0) return kind;
      return a.sourceId.compareTo(b.sourceId);
    });

    return rows;
  }

  Future<BusinessMetrics> businessMetrics(
    ReportPeriod period, {
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final range = periodRange(period, reference);
    final start = range.start.toUtc().toIso8601String();
    final end = range.end.toUtc().toIso8601String();
    final previousStart =
        range.start.subtract(const Duration(days: 7)).toUtc().toIso8601String();
    final previousEnd =
        range.end.subtract(const Duration(days: 7)).toUtc().toIso8601String();

    final salesRows = await _database.rawQuery(
      '''
      SELECT
        COUNT(*) AS bills,
        COALESCE(SUM(total_minor), 0) AS sales_minor
      FROM sale
      WHERE status = 'finalized'
        AND local_created_at >= ?
        AND local_created_at < ?
      ''',
      [start, end],
    );
    final salesMinor = salesRows.single['sales_minor']! as int;
    final billCount = salesRows.single['bills']! as int;

    final paymentRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(p.amount_minor), 0) AS received_minor
      FROM payment p
      INNER JOIN sale s ON s.id = p.sale_id
      WHERE p.status = 'captured'
        AND p.method <> 'customer_credit'
        AND s.local_created_at >= ?
        AND s.local_created_at < ?
      ''',
      [start, end],
    );
    final collectionRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS received_minor
      FROM customer_credit_entry
      WHERE entry_type = 'payment'
        AND occurred_at >= ?
        AND occurred_at < ?
      ''',
      [start, end],
    );
    final moneyReceivedMinor =
        (paymentRows.single['received_minor']! as int) +
        (collectionRows.single['received_minor']! as int);

    final dueRows = await _database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN entry_type IN ('charge', 'correction_increase')
              THEN amount_minor
            ELSE -amount_minor
          END
        ),
        0
      ) AS due_minor
      FROM customer_credit_entry
      ''',
    );
    final moneyDueMinor = dueRows.single['due_minor']! as int;

    final expenseRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS expense_minor
      FROM expense
      WHERE occurred_at >= ? AND occurred_at < ?
      ''',
      [start, end],
    );
    final expensesMinor = expenseRows.single['expense_minor']! as int;
    final refundRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(total_refund_minor), 0) AS refund_minor
      FROM sale_return
      WHERE status = 'finalized'
        AND returned_at >= ?
        AND returned_at < ?
      ''',
      [start, end],
    );
    final refundsMinor = refundRows.single['refund_minor']! as int;

    final costRows = await _database.rawQuery(
      '''
      SELECT
        sl.taxable_minor,
        sl.quantity_milli,
        (
          SELECT prl.unit_cost_minor
          FROM purchase_receipt_line prl
          INNER JOIN purchase_receipt pr
            ON pr.id = prl.purchase_receipt_id
          WHERE prl.product_id = sl.product_id
            AND pr.received_at <= s.local_created_at
          ORDER BY pr.received_at DESC
          LIMIT 1
        ) AS unit_cost_minor
      FROM sale_line sl
      INNER JOIN sale s ON s.id = sl.sale_id
      WHERE s.status = 'finalized'
        AND s.local_created_at >= ?
        AND s.local_created_at < ?
      ''',
      [start, end],
    );

    var taxableSalesMinor = 0;
    var coveredTaxableMinor = 0;
    var estimatedCostMinor = 0;
    for (final row in costRows) {
      final taxable = row['taxable_minor']! as int;
      taxableSalesMinor += taxable;
      final unitCost = row['unit_cost_minor'] as int?;
      if (unitCost != null) {
        coveredTaxableMinor += taxable;
        estimatedCostMinor +=
            (unitCost * (row['quantity_milli']! as int) + 500) ~/ 1000;
      }
    }

    final costCoverageBps = taxableSalesMinor == 0
        ? 10000
        : (coveredTaxableMinor * 10000) ~/ taxableSalesMinor;
    final estimatedProfitMinor =
        coveredTaxableMinor == taxableSalesMinor && refundsMinor == 0
            ? taxableSalesMinor - estimatedCostMinor - expensesMinor
            : null;

    final inventory = await listInventory();
    final lowStockCount = inventory
        .where((item) => item.health != StockHealth.healthy)
        .length;

    final previousRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(total_minor), 0) AS sales_minor
      FROM sale
      WHERE status = 'finalized'
        AND local_created_at >= ?
        AND local_created_at < ?
      ''',
      [previousStart, previousEnd],
    );

    final varianceRows = await _database.rawQuery(
      '''
      SELECT variance_minor
      FROM shift
      WHERE status = 'closed' AND variance_minor IS NOT NULL
      ORDER BY closed_at DESC
      LIMIT 1
      ''',
    );

    return BusinessMetrics(
      period: period,
      salesMinor: salesMinor,
      billCount: billCount,
      moneyReceivedMinor: moneyReceivedMinor,
      moneyDueMinor: moneyDueMinor < 0 ? 0 : moneyDueMinor,
      expensesMinor: expensesMinor,
      refundsMinor: refundsMinor,
      estimatedProfitMinor: estimatedProfitMinor,
      lowStockCount: lowStockCount,
      costCoverageBps: costCoverageBps,
      previousComparableSalesMinor:
          previousRows.single['sales_minor']! as int,
      latestCashVarianceMinor: varianceRows.isEmpty
          ? null
          : varianceRows.single['variance_minor'] as int?,
    );
  }

  Future<List<BusinessTimelineItem>> businessTimeline({
    int limit = 30,
  }) async {
    final items = <BusinessTimelineItem>[];

    final sales = await _database.rawQuery(
      '''
      SELECT invoice_number, total_minor, local_created_at
      FROM sale
      WHERE status = 'finalized'
      ORDER BY local_created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in sales) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['local_created_at']! as String),
          title: 'Sale ${row['invoice_number']}',
          type: 'sale',
          amountMinor: row['total_minor']! as int,
        ),
      );
    }

    final returns = await _database.rawQuery(
      '''
      SELECT return_number, total_refund_minor, returned_at
      FROM sale_return
      WHERE status = 'finalized'
      ORDER BY returned_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in returns) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['returned_at']! as String),
          title: 'Return ${row['return_number']}',
          type: 'sale_return',
          amountMinor: -(row['total_refund_minor']! as int),
        ),
      );
    }

    final expenses = await _database.rawQuery(
      '''
      SELECT category, amount_minor, occurred_at
      FROM expense
      ORDER BY occurred_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in expenses) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['occurred_at']! as String),
          title: 'Expense • ${row['category']}',
          type: 'expense',
          amountMinor: row['amount_minor']! as int,
        ),
      );
    }

    final receipts = await _database.rawQuery(
      '''
      SELECT pr.total_minor, pr.received_at, s.name AS supplier_name
      FROM purchase_receipt pr
      INNER JOIN supplier s ON s.id = pr.supplier_id
      ORDER BY pr.received_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in receipts) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['received_at']! as String),
          title: 'Stock received • ${row['supplier_name']}',
          type: 'purchase_receipt',
          amountMinor: row['total_minor']! as int,
        ),
      );
    }

    final credits = await _database.rawQuery(
      '''
      SELECT cce.amount_minor, cce.occurred_at, c.name
      FROM customer_credit_entry cce
      INNER JOIN customer c ON c.id = cce.customer_id
      WHERE cce.entry_type = 'charge'
      ORDER BY cce.occurred_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in credits) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['occurred_at']! as String),
          title: 'Customer credit • ${row['name']}',
          type: 'customer_credit',
          amountMinor: row['amount_minor']! as int,
        ),
      );
    }

    final shifts = await _database.rawQuery(
      '''
      SELECT e.name, sh.opened_at, sh.closed_at, sh.variance_minor, sh.status
      FROM shift sh
      INNER JOIN employee e ON e.id = sh.employee_id
      ORDER BY sh.opened_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    for (final row in shifts) {
      items.add(
        BusinessTimelineItem(
          occurredAt: DateTime.parse(row['opened_at']! as String),
          title: 'Shift opened • ${row['name']}',
          type: 'shift_open',
        ),
      );
      if (row['closed_at'] != null) {
        items.add(
          BusinessTimelineItem(
            occurredAt: DateTime.parse(row['closed_at']! as String),
            title: 'Shift closed • ${row['name']}',
            type: 'shift_close',
            detail: (row['variance_minor'] as int? ?? 0) == 0
                ? 'Cash matched'
                : 'Cash difference recorded',
            amountMinor: row['variance_minor'] as int?,
          ),
        );
      }
    }

    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items.take(limit).toList();
  }

  Future<List<LocalDataQualityIssue>> dataQualityIssues() async {
    final issues = <LocalDataQualityIssue>[];

    final duplicateProducts = await _database.rawQuery(
      '''
      SELECT lower(trim(name)) AS normalized_name, COUNT(*) AS count
      FROM product
      WHERE active = 1
      GROUP BY lower(trim(name))
      HAVING COUNT(*) > 1
      ''',
    );
    for (final row in duplicateProducts) {
      issues.add(
        LocalDataQualityIssue(
          type: 'duplicate_product',
          message:
              'Duplicate products named "${row['normalized_name']}" may split stock and sales.',
          repairHint: 'Review products and keep one catalogue entry.',
          severity: DataQualitySeverity.warning,
        ),
      );
    }

    final missingPrices = await _database.rawQuery(
      '''
      SELECT name
      FROM product
      WHERE active = 1 AND unit_price_minor = 0
      ORDER BY name
      ''',
    );
    for (final row in missingPrices) {
      issues.add(
        LocalDataQualityIssue(
          type: 'missing_price',
          message: '${row['name']} has no selling price.',
          repairHint: 'Set the selling price before normal billing.',
          severity: DataQualitySeverity.critical,
        ),
      );
    }

    final inventory = await listInventory();
    for (final item in inventory.where((item) => item.onHandMilli < 0)) {
      issues.add(
        LocalDataQualityIssue(
          type: 'negative_stock',
          message: '${item.name} shows stock below zero.',
          repairHint: 'Count stock and record the actual quantity.',
          severity: DataQualitySeverity.warning,
        ),
      );
    }

    final duplicateCustomers = await _database.rawQuery(
      '''
      SELECT mobile_e164, COUNT(*) AS count
      FROM customer
      WHERE mobile_e164 IS NOT NULL AND trim(mobile_e164) <> ''
      GROUP BY mobile_e164
      HAVING COUNT(*) > 1
      ''',
    );
    for (final row in duplicateCustomers) {
      issues.add(
        LocalDataQualityIssue(
          type: 'duplicate_customer',
          message: 'More than one customer uses ${row['mobile_e164']}.',
          repairHint: 'Review customer profiles before sending reminders.',
          severity: DataQualitySeverity.warning,
        ),
      );
    }

    final incompleteSuppliers = await _database.rawQuery(
      '''
      SELECT name
      FROM supplier
      WHERE (mobile_e164 IS NULL OR trim(mobile_e164) = '')
        AND (gstin IS NULL OR trim(gstin) = '')
      ORDER BY name
      ''',
    );
    for (final row in incompleteSuppliers) {
      issues.add(
        LocalDataQualityIssue(
          type: 'incomplete_supplier',
          message: '${row['name']} has no mobile number or GSTIN.',
          repairHint: 'Add supplier contact or tax details when available.',
          severity: DataQualitySeverity.info,
        ),
      );
    }

    return issues;
  }

  Future<AssistantAnswer> assistantAnswer(String question) async {
    final normalized = question.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const AssistantAnswer(
        question: '',
        classification: InsightClassification.fact,
        answer: 'Ask about sales, low stock, customer credit, expenses, or cash.',
        evidence: [
          InsightEvidence(sourceType: 'assistant_capability', value: 'local')
        ],
      );
    }

    if (normalized.contains('sale') ||
        normalized.contains('sell') ||
        normalized.contains('sold')) {
      final metrics = await businessMetrics(ReportPeriod.today);
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer:
            'Today\'s sales are ${formatInr(metrics.salesMinor)} from ${metrics.billCount} bill${metrics.billCount == 1 ? '' : 's'}.',
        evidence: [
          InsightEvidence(
            sourceType: 'sale',
            metric: 'today_sales_minor',
            value: metrics.salesMinor,
            window: 'today',
          ),
          InsightEvidence(
            sourceType: 'sale',
            metric: 'bill_count',
            value: metrics.billCount,
            window: 'today',
          ),
        ],
      );
    }

    if (normalized.contains('refund') || normalized.contains('return')) {
      final metrics = await businessMetrics(ReportPeriod.today);
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer: metrics.refundsMinor == 0
            ? 'No refunds have been recorded today.'
            : 'Refunds recorded today total ${formatInr(metrics.refundsMinor)}.',
        evidence: [
          InsightEvidence(
            sourceType: 'sale_return',
            metric: 'refunds_minor',
            value: metrics.refundsMinor,
            window: 'today',
          ),
        ],
      );
    }

    if (normalized.contains('low stock') ||
        normalized.contains('running out') ||
        normalized.contains('stock')) {
      final inventory = await listInventory();
      final needsAttention = inventory
          .where((item) => item.health != StockHealth.healthy)
          .toList();
      final names = needsAttention.take(5).map((item) => item.name).join(', ');
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer: needsAttention.isEmpty
            ? 'No stock item currently needs attention.'
            : '${needsAttention.length} item${needsAttention.length == 1 ? '' : 's'} need attention: $names.',
        evidence: needsAttention.isEmpty
            ? const [
                InsightEvidence(
                  sourceType: 'stock_movement',
                  metric: 'items_needing_attention',
                  value: 0,
                ),
              ]
            : [
                for (final item in needsAttention.take(10))
                  InsightEvidence(
                    sourceType: 'stock_movement',
                    sourceId: item.productId,
                    metric: 'on_hand_milli',
                    value: item.onHandMilli,
                  ),
              ],
      );
    }

    if (normalized.contains('owe') ||
        normalized.contains('credit') ||
        normalized.contains('due')) {
      final customers = await listCustomers();
      LocalCustomer? matched;
      for (final customer in customers) {
        if (normalized.contains(customer.name.toLowerCase())) {
          matched = customer;
          break;
        }
      }
      if (matched != null) {
        return AssistantAnswer(
          question: question,
          classification: InsightClassification.fact,
          answer:
              '${matched.name} owes ${formatInr(matched.creditBalanceMinor)}. '
              '${matched.overdueMinor > 0 ? '${formatInr(matched.overdueMinor)} is overdue.' : 'Nothing is overdue.'}',
          evidence: [
            InsightEvidence(
              sourceType: 'customer_credit_entry',
              sourceId: matched.id,
              metric: 'balance_minor',
              value: matched.creditBalanceMinor,
            ),
            InsightEvidence(
              sourceType: 'customer_credit_entry',
              sourceId: matched.id,
              metric: 'overdue_minor',
              value: matched.overdueMinor,
            ),
          ],
        );
      }

      final metrics = await businessMetrics(ReportPeriod.today);
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer:
            'Customers currently owe ${formatInr(metrics.moneyDueMinor)} in total.',
        evidence: [
          InsightEvidence(
            sourceType: 'customer_credit_entry',
            metric: 'total_due_minor',
            value: metrics.moneyDueMinor,
          ),
        ],
      );
    }

    if (normalized.contains('expense')) {
      final metrics = await businessMetrics(ReportPeriod.today);
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer:
            'Today\'s recorded expenses are ${formatInr(metrics.expensesMinor)}.',
        evidence: [
          InsightEvidence(
            sourceType: 'expense',
            metric: 'today_expense_minor',
            value: metrics.expensesMinor,
            window: 'today',
          ),
        ],
      );
    }

    if (normalized.contains('cash') ||
        normalized.contains('difference') ||
        normalized.contains('variance')) {
      final metrics = await businessMetrics(ReportPeriod.today);
    final variance = metrics.latestCashVarianceMinor;
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.fact,
        answer: variance == null
            ? 'No closed-shift cash difference is recorded yet.'
            : variance == 0
                ? 'The latest closed shift matched expected cash.'
                : 'The latest closed shift has a ${formatInr(variance.abs())} '
                    '${variance < 0 ? 'shortage' : 'excess'}.',
        evidence: [
          InsightEvidence(
            sourceType: 'shift',
            metric: 'latest_variance_minor',
            value: variance ?? 0,
          ),
        ],
      );
    }

    if (normalized.contains('order') ||
        normalized.contains('buy') ||
        normalized.contains('purchase')) {
      final insights = await generateBusinessInsights();
      final suggestions = insights
          .where((item) => item.type == 'purchase_suggestion')
          .toList();
      return AssistantAnswer(
        question: question,
        classification: InsightClassification.recommendation,
        answer: suggestions.isEmpty
            ? 'Recent sales do not currently support a purchase suggestion.'
            : suggestions.take(3).map((item) => item.message).join(' '),
        evidence: suggestions.isEmpty
            ? const [
                InsightEvidence(
                  sourceType: 'sale_line',
                  metric: 'purchase_suggestions',
                  value: 0,
                  window: 'last_14_days',
                ),
              ]
            : [
                for (final item in suggestions.take(3)) ...item.evidence,
              ],
      );
    }

    return const AssistantAnswer(
      question: '',
      classification: InsightClassification.fact,
      answer:
          'I can answer recorded questions about sales, stock, customer credit, expenses, cash differences and purchase suggestions.',
      evidence: [
        InsightEvidence(sourceType: 'assistant_capability', value: 'local')
      ],
    );
  }

  Future<List<LocalBusinessInsight>> generateBusinessInsights({
    DateTime? now,
  }) async {
    final generatedAt = (now ?? DateTime.now()).toUtc();
    final insights = <LocalBusinessInsight>[];
    final metrics = await businessMetrics(ReportPeriod.today, now: now);

    insights.add(
      LocalBusinessInsight(
        id: 'daily-summary-${generatedAt.toIso8601String()}',
        type: 'daily_summary',
        classification: InsightClassification.fact,
        title: 'Business today',
        message:
            'Sales ${formatInr(metrics.salesMinor)} from ${metrics.billCount} bills; '
            'expenses ${formatInr(metrics.expensesMinor)}; '
            'refunds ${formatInr(metrics.refundsMinor)}.',
        evidence: [
          InsightEvidence(
            sourceType: 'sale',
            metric: 'sales_minor',
            value: metrics.salesMinor,
            window: 'today',
          ),
          InsightEvidence(
            sourceType: 'expense',
            metric: 'expenses_minor',
            value: metrics.expensesMinor,
            window: 'today',
          ),
        ],
        generatedAt: generatedAt,
      ),
    );

    if (metrics.previousComparableSalesMinor > 0) {
      final delta = metrics.salesMinor - metrics.previousComparableSalesMinor;
      final direction = delta.abs() * 10000 ~/
          metrics.previousComparableSalesMinor;
      if (direction >= 500) {
        insights.add(
          LocalBusinessInsight(
            id: 'sales-comparison-${generatedAt.toIso8601String()}',
            type: 'sales_comparison',
            classification: InsightClassification.calculation,
            title: delta < 0 ? 'Sales are lower' : 'Sales are higher',
            message:
                'Sales are ${formatInr(delta.abs())} ${delta < 0 ? 'lower' : 'higher'} '
                'than the same period one week earlier.',
            evidence: [
              InsightEvidence(
                sourceType: 'sale',
                metric: 'current_sales_minor',
                value: metrics.salesMinor,
                window: 'today',
              ),
              InsightEvidence(
                sourceType: 'sale',
                metric: 'comparison_sales_minor',
                value: metrics.previousComparableSalesMinor,
                window: 'same_period_last_week',
              ),
            ],
            generatedAt: generatedAt,
          ),
        );
      }
    }

    final start = generatedAt.subtract(const Duration(days: 14)).toIso8601String();
    final recommendationRows = await _database.rawQuery(
      '''
      SELECT
        p.id,
        p.name,
        COALESCE((
          SELECT SUM(sm.quantity_delta_milli)
          FROM stock_movement sm
          WHERE sm.product_id = p.id
        ), 0) AS on_hand_milli,
        COALESCE((
          SELECT SUM(sl.quantity_milli)
          FROM sale_line sl
          INNER JOIN sale s ON s.id = sl.sale_id
          WHERE sl.product_id = p.id
            AND s.status = 'finalized'
            AND s.local_created_at >= ?
        ), 0) AS sold_milli
      FROM product p
      WHERE p.active = 1
      ORDER BY p.name COLLATE NOCASE
      ''',
      [start],
    );

    for (final row in recommendationRows) {
      final soldMilli = row['sold_milli']! as int;
      if (soldMilli <= 0) continue;
      final averageDailySoldMilli = (soldMilli / 14).ceil();
      final onHandMilli = row['on_hand_milli']! as int;
      final targetMilli = averageDailySoldMilli * 7;
      final suggestedMilli =
          targetMilli > onHandMilli ? targetMilli - onHandMilli : 0;
      if (suggestedMilli <= 0) continue;

      final daysCover = onHandMilli <= 0
          ? 0
          : onHandMilli ~/ averageDailySoldMilli;
      insights.add(
        LocalBusinessInsight(
          id: 'purchase-${row['id']}-${generatedAt.toIso8601String()}',
          type: 'purchase_suggestion',
          classification: InsightClassification.recommendation,
          title: 'Consider ordering ${row['name']}',
          message:
              '${row['name']} has about $daysCover day${daysCover == 1 ? '' : 's'} '
              'of stock at the recent sales rate. Consider ordering '
              '${_formatMilliQuantity(suggestedMilli)} units for about 7 days of coverage.',
          evidence: [
            InsightEvidence(
              sourceType: 'stock_movement',
              sourceId: row['id']! as String,
              metric: 'on_hand_milli',
              value: onHandMilli,
            ),
            InsightEvidence(
              sourceType: 'sale_line',
              sourceId: row['id']! as String,
              metric: 'sold_milli',
              value: soldMilli,
              window: 'last_14_days',
            ),
            const InsightEvidence(
              sourceType: 'calculation',
              metric: 'target_coverage_days',
              value: 7,
            ),
          ],
          generatedAt: generatedAt,
        ),
      );
    }

    final winBackThreshold =
        generatedAt.subtract(const Duration(days: 30)).toIso8601String();
    final winBackRows = await _database.rawQuery(
      '''
      SELECT
        c.id,
        c.name,
        COUNT(s.id) AS purchase_count,
        MAX(s.local_created_at) AS last_purchase
      FROM customer c
      INNER JOIN sale s ON s.customer_id = c.id
      WHERE s.status = 'finalized'
      GROUP BY c.id, c.name
      HAVING COUNT(s.id) >= 2
        AND MAX(s.local_created_at) < ?
      ORDER BY last_purchase
      ''',
      [winBackThreshold],
    );
    if (winBackRows.isNotEmpty) {
      insights.add(
        LocalBusinessInsight(
          id: 'winback-${generatedAt.toIso8601String()}',
          type: 'customer_winback',
          classification: InsightClassification.recommendation,
          title: 'Customers may be worth reconnecting with',
          message:
              '${winBackRows.length} previously repeat customer'
              '${winBackRows.length == 1 ? '' : 's'} have not purchased in 30 days.',
          evidence: [
            for (final row in winBackRows.take(10))
              InsightEvidence(
                sourceType: 'sale',
                sourceId: row['id']! as String,
                metric: 'last_purchase',
                value: row['last_purchase']! as String,
                window: 'customer_history',
              ),
          ],
          generatedAt: generatedAt,
        ),
      );
    }

    final localGeneratedAt = generatedAt.toLocal();
    final todayStart = DateTime(
    localGeneratedAt.year,
    localGeneratedAt.month,
    localGeneratedAt.day,
    ).toUtc();
    final tomorrow = todayStart.add(const Duration(days: 1));
    final priorStart = todayStart.subtract(const Duration(days: 7));
    final refundTodayRows = await _database.rawQuery(
    '''
    SELECT COUNT(*) AS count, COALESCE(SUM(total_refund_minor), 0) AS amount
    FROM sale_return
    WHERE status = 'finalized'
      AND returned_at >= ?
      AND returned_at < ?
    ''',
    [todayStart.toIso8601String(), tomorrow.toIso8601String()],
    );
    final refundPriorRows = await _database.rawQuery(
    '''
    SELECT COUNT(*) AS count
    FROM sale_return
    WHERE status = 'finalized'
      AND returned_at >= ?
      AND returned_at < ?
    ''',
    [priorStart.toIso8601String(), todayStart.toIso8601String()],
    );
    final refundCount = refundTodayRows.single['count']! as int;
    final refundAmount = refundTodayRows.single['amount']! as int;
    final priorRefundCount = refundPriorRows.single['count']! as int;
    final refundRateBps = metrics.salesMinor <= 0
      ? 0
      : refundAmount * 10000 ~/ metrics.salesMinor;
    final unusualCount = refundCount >= 3 &&
      (priorRefundCount == 0 || refundCount * 7 >= priorRefundCount * 2);
    final unusualAmount = refundAmount >= 50000 && refundRateBps >= 1000;
    if (unusualCount || unusualAmount) {
    insights.add(
      LocalBusinessInsight(
        id: 'refund-anomaly-${generatedAt.toIso8601String()}',
        type: 'refund_anomaly',
        classification: InsightClassification.calculation,
        title: 'Refund activity needs attention',
        message:
            '$refundCount refund${refundCount == 1 ? '' : 's'} totaling '
            '${formatInr(refundAmount)} were recorded today.',
        evidence: [
          InsightEvidence(
            sourceType: 'sale_return',
            metric: 'today_refund_count',
            value: refundCount,
            window: 'today',
          ),
          InsightEvidence(
            sourceType: 'sale_return',
            metric: 'today_refund_minor',
            value: refundAmount,
            window: 'today',
          ),
          InsightEvidence(
            sourceType: 'sale_return',
            metric: 'prior_7_day_refund_count',
            value: priorRefundCount,
            window: 'prior_7_days',
          ),
        ],
        generatedAt: generatedAt,
      ),
    );
    }

    final variance = metrics.latestCashVarianceMinor;
    if (variance != null && variance.abs() > 50000) {
      insights.add(
        LocalBusinessInsight(
          id: 'cash-anomaly-${generatedAt.toIso8601String()}',
          type: 'cash_anomaly',
          classification: InsightClassification.calculation,
          title: 'Cash difference needs attention',
          message:
              'The latest closed shift differs by ${formatInr(variance.abs())} '
              'from expected cash.',
          evidence: [
            InsightEvidence(
              sourceType: 'shift',
              metric: 'variance_minor',
              value: variance,
            ),
          ],
          generatedAt: generatedAt,
        ),
      );
    }

    return insights;
  }

  String _formatMilliQuantity(int milli) {
    final whole = milli ~/ 1000;
    final fraction = (milli % 1000).toString().padLeft(3, '0');
    if (fraction == '000') return '$whole';
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return '$whole.$trimmed';
  }

  Future<String> holdSale({
    required List<SaleLineInput> lines,
    String? customerId,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Cannot hold an empty bill');
    }
    final heldSaleId = _uuid.v4();
    final heldAt = DateTime.now().toUtc();
    await _database.transaction((txn) async {
      if (customerId != null) {
        final customer = await txn.query(
          'customer',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customer.isEmpty) {
          throw StateError('Customer not found');
        }
      }
      await txn.insert('held_sale', {
        'id': heldSaleId,
        'customer_id': customerId,
        'held_at': heldAt.toIso8601String(),
      });
      for (final line in lines) {
        await txn.insert('held_sale_line', {
          'id': _uuid.v4(),
          'held_sale_id': heldSaleId,
          'product_id': line.product.id,
          'product_name_snapshot': line.product.name,
          'quantity_milli': line.quantityMilli,
          'unit_price_minor': line.product.unitPriceMinor,
          'discount_minor': line.discountMinor,
          'discount_source': line.discountSource,
          'discount_reference_id': line.discountReferenceId,
          'tax_rate_bps': line.product.taxRateBps,
          'tax_price_mode': line.product.taxPriceMode == TaxPriceMode.exclusive
              ? 'exclusive'
              : 'inclusive',
          'tax_classification_type': line.product.taxClassificationType == null
              ? null
              : taxClassificationTypeValue(
                  line.product.taxClassificationType!,
                ),
          'tax_classification_code': line.product.taxClassificationCode,
          'tax_rule_version_id': line.product.taxRuleVersionId,
        });
      }
    });
    return heldSaleId;
  }

  Future<HeldSale> _readHeldSale(
    DatabaseExecutor executor,
    String heldSaleId,
  ) async {
    final headers = await executor.rawQuery(
      '''
      SELECT hs.*, c.name AS customer_name
      FROM held_sale hs
      LEFT JOIN customer c ON c.id = hs.customer_id
      WHERE hs.id = ?
      ''',
      [heldSaleId],
    );
    if (headers.isEmpty) {
      throw StateError('Held bill not found');
    }
    final header = headers.single;
    final rows = await executor.rawQuery(
      '''
      SELECT hsl.*, p.barcode
      FROM held_sale_line hsl
      INNER JOIN product p ON p.id = hsl.product_id
      WHERE hsl.held_sale_id = ?
      ORDER BY hsl.id
      ''',
      [heldSaleId],
    );
    return HeldSale(
      id: heldSaleId,
      heldAt: DateTime.parse(header['held_at']! as String),
      customerId: header['customer_id'] as String?,
      customerName: header['customer_name'] as String?,
      lines: rows
          .map(
            (row) => SaleLineInput(
              product: Product(
                id: row['product_id']! as String,
                name: row['product_name_snapshot']! as String,
                barcode: row['barcode'] as String?,
                unitPriceMinor: row['unit_price_minor']! as int,
                taxRateBps: row['tax_rate_bps']! as int,
                taxPriceMode: row['tax_price_mode'] == 'exclusive'
                    ? TaxPriceMode.exclusive
                    : TaxPriceMode.inclusive,
                taxClassificationType: taxClassificationTypeFromValue(
                  row['tax_classification_type'] as String?,
                ),
                taxClassificationCode:
                    row['tax_classification_code'] as String?,
                taxRuleVersionId: row['tax_rule_version_id'] as String?,
              ),
              quantityMilli: row['quantity_milli']! as int,
              discountMinor: row['discount_minor']! as int,
              discountSource: row['discount_source'] as String?,
              discountReferenceId: row['discount_reference_id'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<List<HeldSale>> listHeldSales() async {
    final rows = await _database.query(
      'held_sale',
      columns: ['id'],
      orderBy: 'held_at DESC',
    );
    final result = <HeldSale>[];
    for (final row in rows) {
      result.add(await _readHeldSale(_database, row['id']! as String));
    }
    return result;
  }

  Future<HeldSale> resumeHeldSale(String heldSaleId) {
    return _database.transaction((txn) async {
      final held = await _readHeldSale(txn, heldSaleId);
      await txn.delete(
        'held_sale',
        where: 'id = ?',
        whereArgs: [heldSaleId],
      );
      return held;
    });
  }

  Future<List<ReturnableSale>> listReturnableSales({
    String query = '',
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    final saleRows = await _database.rawQuery(
      '''
      SELECT
        s.id,
        s.invoice_number,
        s.local_created_at,
        s.total_minor,
        s.customer_id,
        c.name AS customer_name,
        p.method AS payment_method
      FROM sale s
      INNER JOIN payment p ON p.sale_id = s.id
      LEFT JOIN customer c ON c.id = s.customer_id
      WHERE (? = '' OR s.invoice_number LIKE ? OR c.name LIKE ?)
      ORDER BY s.local_created_at DESC
      LIMIT ?
      ''',
      [trimmed, '%$trimmed%', '%$trimmed%', limit],
    );

    final result = <ReturnableSale>[];
    for (final sale in saleRows) {
      final saleId = sale['id']! as String;
      final lineRows = await _database.rawQuery(
        '''
        SELECT
          sl.*,
          COALESCE((
            SELECT SUM(srl.quantity_milli)
            FROM sale_return_line srl
            INNER JOIN sale_return sr ON sr.id = srl.sale_return_id
            WHERE srl.sale_line_id = sl.id
              AND sr.status = 'finalized'
          ), 0) AS returned_quantity_milli
        FROM sale_line sl
        WHERE sl.sale_id = ?
        ORDER BY sl.id
        ''',
        [saleId],
      );
      final lines = lineRows
          .map(
            (row) => ReturnableSaleLine(
              saleLineId: row['id']! as String,
              productId: row['product_id']! as String,
              productName: row['product_name_snapshot']! as String,
              soldQuantityMilli: row['quantity_milli']! as int,
              returnedQuantityMilli:
                  row['returned_quantity_milli']! as int,
              taxableMinor: row['taxable_minor']! as int,
              cgstMinor: row['cgst_minor']! as int,
              sgstMinor: row['sgst_minor']! as int,
              igstMinor: row['igst_minor']! as int,
              taxMinor: row['tax_minor']! as int,
              totalMinor: row['total_minor']! as int,
            ),
          )
          .where((line) => line.remainingQuantityMilli > 0)
          .toList();
      if (lines.isEmpty) continue;
      result.add(
        ReturnableSale(
          saleId: saleId,
          invoiceNumber: sale['invoice_number']! as String,
          createdAt: DateTime.parse(sale['local_created_at']! as String),
          totalMinor: sale['total_minor']! as int,
          paymentMethod: sale['payment_method']! as String,
          customerId: sale['customer_id'] as String?,
          customerName: sale['customer_name'] as String?,
          lines: lines,
        ),
      );
    }
    return result;
  }

  Future<int> _saleCreditOutstanding(
    DatabaseExecutor executor, {
    required String customerId,
    required String saleId,
  }) async {
    final rows = await executor.query(
      'customer_credit_entry',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'occurred_at, id',
    );
    final charges = <Map<String, Object?>>[];

    void applyFifo(int amount) {
      var remaining = amount;
      for (final charge in charges) {
        if (remaining <= 0) break;
        final open = charge['remaining']! as int;
        if (open <= 0) continue;
        final applied = open < remaining ? open : remaining;
        charge['remaining'] = open - applied;
        remaining -= applied;
      }
    }

    for (final row in rows) {
      final type = row['entry_type']! as String;
      final amount = row['amount_minor']! as int;
      final linkedSaleId = row['sale_id'] as String?;
      if (type == 'charge' || type == 'correction_increase') {
        charges.add({
          'sale_id': linkedSaleId,
          'remaining': amount,
        });
      } else if (type == 'correction_decrease' && linkedSaleId != null) {
        var remaining = amount;
        for (final charge in charges) {
          if (remaining <= 0) break;
          if (charge['sale_id'] != linkedSaleId) continue;
          final open = charge['remaining']! as int;
          final applied = open < remaining ? open : remaining;
          charge['remaining'] = open - applied;
          remaining -= applied;
        }
        if (remaining > 0) applyFifo(remaining);
      } else {
        applyFifo(amount);
      }
    }

    return charges
        .where((charge) => charge['sale_id'] == saleId)
        .fold<int>(0, (sum, charge) => sum + (charge['remaining']! as int));
  }

  Future<OfflineReturnResult> processReturn({
    required LocalSaleContext context,
    required String saleId,
    required List<ReturnLineRequest> requests,
    required String reason,
    int cashierApprovalThresholdMinor = 500000,
  }) async {
    if (requests.isEmpty || reason.trim().isEmpty) {
      throw ArgumentError('Return items and reason are required');
    }
    final returnId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();
    late String returnNumber;
    late int refundMinor;
    var cashRefundMinor = 0;
    var creditReversalMinor = 0;
    var loyaltyEarnedPointsReversed = 0;
    var loyaltyRedeemedPointsRestored = 0;

    await _database.transaction((txn) async {
      final sales = await txn.rawQuery(
        '''
        SELECT
          s.*,
          p.method AS payment_method,
          c.name AS customer_name
        FROM sale s
        INNER JOIN payment p ON p.sale_id = s.id
        LEFT JOIN customer c ON c.id = s.customer_id
        WHERE s.id = ?
        LIMIT 1
        ''',
        [saleId],
      );
      if (sales.isEmpty) {
        throw StateError('Original bill not found');
      }
      final sale = sales.single;

      final employeeRows = await txn.query(
        'employee',
        columns: ['role'],
        where: 'id = ? AND active = 1',
        whereArgs: [context.userId],
        limit: 1,
      );
      if (employeeRows.isEmpty) {
        throw StateError('Active cashier identity not found');
      }
      final role = employeeRows.single['role']! as String;

      final prepared = <Map<String, Object?>>[];
      var total = 0;
      for (final request in requests) {
        final lines = await txn.query(
          'sale_line',
          where: 'id = ? AND sale_id = ?',
          whereArgs: [request.saleLineId, saleId],
          limit: 1,
        );
        if (lines.isEmpty) {
          throw StateError('Sale item not found');
        }
        final line = lines.single;
        final returnedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(srl.quantity_milli), 0) AS quantity_milli
          FROM sale_return_line srl
          INNER JOIN sale_return sr ON sr.id = srl.sale_return_id
          WHERE srl.sale_line_id = ? AND sr.status = 'finalized'
          ''',
          [request.saleLineId],
        );
        final soldQuantity = line['quantity_milli']! as int;
        final alreadyReturned =
            returnedRows.single['quantity_milli']! as int;
        final remaining = soldQuantity - alreadyReturned;
        if (request.quantityMilli <= 0 || request.quantityMilli > remaining) {
          throw StateError('Return quantity exceeds what was sold');
        }

        int prorate(String column) => prorateReturnMinor(
              originalMinor: line[column]! as int,
              partQuantityMilli: request.quantityMilli,
              originalQuantityMilli: soldQuantity,
            );

        final item = <String, Object?>{
          'sale_line_id': request.saleLineId,
          'product_id': line['product_id'],
          'quantity_milli': request.quantityMilli,
          'taxable_minor': prorate('taxable_minor'),
          'cgst_minor': prorate('cgst_minor'),
          'sgst_minor': prorate('sgst_minor'),
          'igst_minor': prorate('igst_minor'),
          'tax_minor': prorate('tax_minor'),
          'total_minor': prorate('total_minor'),
        };
        total += item['total_minor']! as int;
        prepared.add(item);
      }

      if (role == 'cashier' && total > cashierApprovalThresholdMinor) {
        final fingerprint = buildApprovalFingerprint(
          actionType: 'refund',
          entityId: saleId,
          facts: [
            for (final request in requests)
              '${request.saleLineId}:${request.quantityMilli}',
            'amount:$total',
          ],
        );
        await _consumeApproval(
          txn,
          context: context,
          actionType: 'refund',
          entityType: 'sale',
          entityId: saleId,
          actionFingerprint: fingerprint,
          now: now,
        );
      }
      if (role == 'stock_worker') {
        throw StateError('This role cannot refund sales');
      }

      final sequenceRows = await txn.query(
        'return_sequence',
        columns: ['next_return'],
        where: 'terminal_code = ?',
        whereArgs: [context.terminalCode],
        limit: 1,
      );
      if (sequenceRows.isEmpty) {
        throw StateError('Return sequence is missing');
      }
      final nextReturn = sequenceRows.single['next_return']! as int;
      returnNumber =
          'R-${context.terminalCode}-${nextReturn.toString().padLeft(6, '0')}';
      await txn.update(
        'return_sequence',
        {'next_return': nextReturn + 1},
        where: 'terminal_code = ?',
        whereArgs: [context.terminalCode],
      );

      refundMinor = total;
      final paymentMethod = sale['payment_method']! as String;
      if (paymentMethod == 'cash') {
        cashRefundMinor = total;
      } else if (paymentMethod == 'customer_credit') {
        final customerId = sale['customer_id'] as String?;
        if (customerId == null) {
          throw StateError('Credit sale customer is missing');
        }
        final outstanding = await _saleCreditOutstanding(
          txn,
          customerId: customerId,
          saleId: saleId,
        );
        creditReversalMinor = outstanding < total ? outstanding : total;
        cashRefundMinor = total - creditReversalMinor;
      } else {
        throw StateError(
          'Provider refund is not configured for this payment method',
        );
      }

      await txn.insert('sale_return', {
        'id': returnId,
        'sale_id': saleId,
        'return_number': returnNumber,
        'reason': reason.trim(),
        'total_refund_minor': total,
        'status': 'finalized',
        'returned_at': now.toIso8601String(),
        'idempotency_key': idempotencyKey,
      });

      for (final item in prepared) {
        await txn.insert('sale_return_line', {
          'id': _uuid.v4(),
          'sale_return_id': returnId,
          ...item,
        });
        await txn.insert('stock_movement', {
          'id': _uuid.v4(),
          'product_id': item['product_id'],
          'movement_type': 'return_in',
          'quantity_delta_milli': item['quantity_milli'],
          'reason': reason.trim(),
          'source_entity_type': 'sale_return',
          'source_entity_id': returnId,
          'occurred_at': now.toIso8601String(),
          'idempotency_key':
              'sale-return:$returnId:${item['sale_line_id']}',
        });
      }

      final shiftId = await _openShiftId(txn);
      if (creditReversalMinor > 0) {
        final customerId = sale['customer_id']! as String;
        final entryId = _uuid.v4();
        await txn.insert('customer_credit_entry', {
          'id': entryId,
          'customer_id': customerId,
          'entry_type': 'correction_decrease',
          'amount_minor': creditReversalMinor,
          'sale_id': saleId,
          'note': 'Return $returnNumber',
          'occurred_at': now.toIso8601String(),
          'idempotency_key': 'credit-return:$returnId',
        });
        await txn.insert('refund', {
          'id': _uuid.v4(),
          'sale_return_id': returnId,
          'method': 'customer_credit',
          'amount_minor': creditReversalMinor,
          'status': 'captured',
          'created_at': now.toIso8601String(),
          'idempotency_key': 'refund-credit:$returnId',
        });
      }
      if (cashRefundMinor > 0) {
        await txn.insert('refund', {
          'id': _uuid.v4(),
          'sale_return_id': returnId,
          'shift_id': shiftId,
          'method': 'cash',
          'amount_minor': cashRefundMinor,
          'status': 'captured',
          'created_at': now.toIso8601String(),
          'idempotency_key': 'refund-cash:$returnId',
        });
      }

      final loyaltyRows = await txn.query(
        'sale_loyalty',
        where: 'sale_id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (loyaltyRows.isNotEmpty) {
        final loyalty = loyaltyRows.single;
        final pointsEarned = loyalty['points_earned']! as int;
        final pointsRedeemed = loyalty['points_redeemed']! as int;
        final customerId = loyalty['customer_id']! as String;

        final refundRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(total_refund_minor), 0) AS total
          FROM sale_return
          WHERE sale_id = ? AND status = 'finalized'
          ''',
          [saleId],
        );
        final cumulativeRefund = refundRows.single['total']! as int;
        final saleTotal = sale['total_minor']! as int;

        if (pointsEarned > 0) {
          final targetReversal = saleTotal <= 0
              ? pointsEarned
              : (pointsEarned * cumulativeRefund + saleTotal ~/ 2) ~/
                  saleTotal;
          final reversedRows = await txn.rawQuery(
            '''
            SELECT COALESCE(SUM(points), 0) AS points
            FROM customer_loyalty_entry
            WHERE sale_id = ? AND entry_type = 'adjustment_out'
            ''',
            [saleId],
          );
          final alreadyReversed = reversedRows.single['points']! as int;
          final pointsToReverse = targetReversal - alreadyReversed;
          if (pointsToReverse > 0) {
            loyaltyEarnedPointsReversed = pointsToReverse;
            await txn.insert('customer_loyalty_entry', {
              'id': _uuid.v4(),
              'customer_id': customerId,
              'entry_type': 'adjustment_out',
              'points': pointsToReverse,
              'sale_id': saleId,
              'note': 'Earned points reversed on $returnNumber',
              'occurred_at': now.toIso8601String(),
              'idempotency_key': 'loyalty-earn-return:$returnId',
            });
          }
        }

        if (pointsRedeemed > 0) {
          final targetRestore = saleTotal <= 0
              ? pointsRedeemed
              : (pointsRedeemed * cumulativeRefund + saleTotal ~/ 2) ~/
                  saleTotal;
          final restoredRows = await txn.rawQuery(
            '''
            SELECT COALESCE(SUM(points), 0) AS points
            FROM customer_loyalty_entry
            WHERE sale_id = ? AND entry_type = 'adjustment_in'
              AND note LIKE 'Redeemed points restored%'
            ''',
            [saleId],
          );
          final alreadyRestored = restoredRows.single['points']! as int;
          final pointsToRestore = targetRestore - alreadyRestored;
          if (pointsToRestore > 0) {
            loyaltyRedeemedPointsRestored = pointsToRestore;
            await txn.insert('customer_loyalty_entry', {
              'id': _uuid.v4(),
              'customer_id': customerId,
              'entry_type': 'adjustment_in',
              'points': pointsToRestore,
              'sale_id': saleId,
              'note': 'Redeemed points restored on $returnNumber',
              'occurred_at': now.toIso8601String(),
              'idempotency_key': 'loyalty-redeem-return:$returnId',
            });
          }
        }
      }

      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'sale_return',
        'entity_id': returnId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'saleReturnId': returnId,
          'saleId': saleId,
          'returnNumber': returnNumber,
          'reason': reason.trim(),
          'returnedAt': now.toIso8601String(),
          'refundMinor': total,
          'cashRefundMinor': cashRefundMinor,
          'creditReversalMinor': creditReversalMinor,
          'loyaltyEarnedPointsReversed': loyaltyEarnedPointsReversed,
          'loyaltyRedeemedPointsRestored': loyaltyRedeemedPointsRestored,
          'lines': prepared,
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'sale.returned',
        entityType: 'sale_return',
        entityId: returnId,
        occurredAt: now,
        metadata: {'reference': returnNumber, 'saleId': saleId, 'refundMinor': total},
      );
    });

    return OfflineReturnResult(
      returnId: returnId,
      returnNumber: returnNumber,
      refundMinor: refundMinor,
      cashRefundMinor: cashRefundMinor,
      creditReversalMinor: creditReversalMinor,
    );
  }

  Future<int> returnCountForSale(String saleId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM sale_return
      WHERE sale_id = ? AND status = 'finalized'
      ''',
      [saleId],
    );
    return rows.single['count']! as int;
  }

  Future<int> loyaltyEntryCountForCustomer(String customerId) async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM customer_loyalty_entry WHERE customer_id = ?',
      [customerId],
    );
    return rows.single['count']! as int;
  }

  Future<int> promotionRedemptionCountForSale(String saleId) async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM promotion_redemption WHERE sale_id = ?',
      [saleId],
    );
    return rows.single['count']! as int;
  }

  Future<List<LocalOutboxItem>> listOutboxItems({
    bool unresolvedOnly = true,
    int limit = 100,
  }) async {
    final rows = await _database.query(
      'sync_outbox',
      where: unresolvedOnly
          ? "state IN ('pending', 'sending', 'conflict', 'rejected')"
          : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => LocalOutboxItem(
            id: row['id']! as String,
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            idempotencyKey: row['idempotency_key']! as String,
            schemaVersion: row['schema_version']! as int,
            state: localSyncStateFromValue(row['state']! as String),
            createdAt: DateTime.parse(row['created_at']! as String),
            attemptCount: row['attempt_count']! as int,
            lastAttemptAt: row['last_attempt_at'] == null
                ? null
                : DateTime.parse(row['last_attempt_at']! as String),
            serverMessage: row['last_error'] as String?,
          ),
        )
        .toList();
  }

  Future<void> markOutboxSending(String id) async {
    final rows = await _database.query(
      'sync_outbox',
      columns: ['state', 'attempt_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Outbox item not found');
    final current = localSyncStateFromValue(rows.single['state']! as String);
    final next = nextLocalSyncState(current, 'send');
    await _database.update(
      'sync_outbox',
      {
        'state': localSyncStateValue(next),
        'attempt_count': (rows.single['attempt_count']! as int) + 1,
        'last_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> applySyncAcknowledgement(
    LocalSyncAcknowledgement acknowledgement,
  ) async {
    if (acknowledgement.state != LocalSyncState.acknowledged &&
        acknowledgement.state != LocalSyncState.conflict &&
        acknowledgement.state != LocalSyncState.rejected) {
      throw ArgumentError('Acknowledgement must be terminal');
    }

    final rows = await _database.query(
      'sync_outbox',
      columns: ['id', 'entity_id', 'state'],
      where: 'idempotency_key = ?',
      whereArgs: [acknowledgement.idempotencyKey],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Outbox item not found');
    if (rows.single['entity_id'] != acknowledgement.entityId) {
      throw StateError('Acknowledgement entity does not match outbox item');
    }

    final current = localSyncStateFromValue(rows.single['state']! as String);
    final event = switch (acknowledgement.state) {
      LocalSyncState.acknowledged => 'acknowledge',
      LocalSyncState.conflict => 'conflict',
      LocalSyncState.rejected => 'reject',
      _ => throw StateError('Unexpected acknowledgement state'),
    };
    final next = nextLocalSyncState(current, event);
    await _database.update(
      'sync_outbox',
      {
        'state': localSyncStateValue(next),
        'last_error': acknowledgement.message ?? acknowledgement.code,
      },
      where: 'id = ?',
      whereArgs: [rows.single['id']],
    );
  }

  Future<void> retryOutbox(String id) async {
    final rows = await _database.query(
      'sync_outbox',
      columns: ['state'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Outbox item not found');
    final current = localSyncStateFromValue(rows.single['state']! as String);
    final next = nextLocalSyncState(current, 'retry');
    await _database.update(
      'sync_outbox',
      {
        'state': localSyncStateValue(next),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> canReadDiagnostics(LocalSaleContext context) async {
    return canReadAudit(context);
  }

  Future<LocalDiagnosticsSnapshot> diagnosticsSnapshot({
    DateTime? now,
  }) async {
    final generatedAt = (now ?? DateTime.now()).toUtc();

    final integrityRows = await _database.rawQuery('PRAGMA quick_check');
    final integrityValue = integrityRows.isEmpty
        ? null
        : integrityRows.single.values.first?.toString().toLowerCase();

    final foreignKeyRows = await _database.rawQuery('PRAGMA foreign_keys');
    final foreignKeysEnabled = foreignKeyRows.isNotEmpty &&
        foreignKeyRows.single.values.first == 1;

    final versionRows = await _database.rawQuery('PRAGMA user_version');
    final schemaVersion = versionRows.isEmpty
        ? 0
        : (versionRows.single.values.first as int?) ?? 0;

    final productRows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM product WHERE active = 1',
    );
    final saleRows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM sale WHERE status = 'finalized'",
    );
    final auditRows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM local_audit_event',
    );
    final shiftRows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM shift WHERE status = 'open'",
    );
    final oldestRows = await _database.rawQuery(
      '''
      SELECT MIN(created_at) AS oldest
      FROM sync_outbox
      WHERE state IN ('pending', 'sending', 'conflict', 'rejected')
      ''',
    );
    final oldestValue =
        oldestRows.isEmpty ? null : oldestRows.single['oldest'] as String?;

    return LocalDiagnosticsSnapshot(
      generatedAt: generatedAt,
      databaseIntegrityOk: integrityValue == 'ok',
      foreignKeysEnabled: foreignKeysEnabled,
      schemaVersion: schemaVersion,
      outboxCounts: await outboxStateCounts(),
      productCount: (productRows.single['count'] as int?) ?? 0,
      finalizedSaleCount: (saleRows.single['count'] as int?) ?? 0,
      auditEventCount: (auditRows.single['count'] as int?) ?? 0,
      openShiftCount: (shiftRows.single['count'] as int?) ?? 0,
      oldestUnresolvedAt:
          oldestValue == null ? null : DateTime.tryParse(oldestValue),
    );
  }

  Future<Map<LocalSyncState, int>> outboxStateCounts() async {
    final rows = await _database.rawQuery(
      '''
      SELECT state, COUNT(*) AS count
      FROM sync_outbox
      GROUP BY state
      ''',
    );
    final result = {
      for (final state in LocalSyncState.values) state: 0,
    };
    for (final row in rows) {
      result[localSyncStateFromValue(row['state']! as String)] =
          row['count']! as int;
    }
    return result;
  }

  Future<int> pendingOutboxCount() async {
    final rows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_outbox WHERE state = 'pending'",
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  Future<List<SaleTaxSnapshot>> saleTaxSnapshots(String saleId) async {
    final normalized = saleId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('saleId is required');
    }

    final rows = await _database.query(
      'sale_line',
      columns: [
        'id',
        'product_id',
        'tax_rate_bps_snapshot',
        'tax_price_mode_snapshot',
        'tax_classification_type_snapshot',
        'tax_classification_code_snapshot',
        'tax_rule_version_id_snapshot',
      ],
      where: 'sale_id = ?',
      whereArgs: [normalized],
      orderBy: 'id',
    );

    return rows
        .map(
          (row) => SaleTaxSnapshot(
            saleLineId: row['id']! as String,
            productId: row['product_id']! as String,
            rateBps: row['tax_rate_bps_snapshot'] as int?,
            priceMode: switch (row['tax_price_mode_snapshot']) {
              'inclusive' => TaxPriceMode.inclusive,
              'exclusive' => TaxPriceMode.exclusive,
              _ => null,
            },
            classificationType: taxClassificationTypeFromValue(
              row['tax_classification_type_snapshot'] as String?,
            ),
            classificationCode:
                row['tax_classification_code_snapshot'] as String?,
            taxRuleVersionId: row['tax_rule_version_id_snapshot'] as String?,
          ),
        )
        .toList();
  }

  Future<int> paymentEventCountForSale(String saleId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM payment_event pe
      INNER JOIN payment p ON p.id = pe.payment_id
      WHERE p.sale_id = ?
      ''',
      [saleId],
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  Future<List<LocalInventoryItem>> listInventory() async {
    final rows = await _database.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.barcode,
        p.reorder_level_milli,
        COALESCE(SUM(sm.quantity_delta_milli), 0) AS on_hand_milli
      FROM product p
      LEFT JOIN stock_movement sm ON sm.product_id = p.id
      WHERE p.active = 1
      GROUP BY p.id, p.name, p.barcode, p.reorder_level_milli
      ORDER BY p.name COLLATE NOCASE
    ''');
    return rows
        .map(
          (row) => LocalInventoryItem(
            productId: row['id']! as String,
            name: row['name']! as String,
            barcode: row['barcode'] as String?,
            onHandMilli: row['on_hand_milli']! as int,
            reorderLevelMilli: row['reorder_level_milli']! as int,
          ),
        )
        .toList();
  }

  Future<void> setReorderLevel({
    required String productId,
    required int reorderLevelMilli,
  }) async {
    if (reorderLevelMilli < 0) {
      throw ArgumentError('Reorder level cannot be negative');
    }
    await _database.update(
      'product',
      {'reorder_level_milli': reorderLevelMilli},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<String> _insertStockMovement(
    DatabaseExecutor executor, {
    required LocalSaleContext context,
    required String productId,
    required StockMovementType type,
    required int quantityDeltaMilli,
    String? reason,
    String? sourceEntityType,
    String? sourceEntityId,
  }) async {
    validateStockMovement(
      type: type,
      quantityDeltaMilli: quantityDeltaMilli,
      reason: reason,
    );
    final movementId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();

    await executor.insert('stock_movement', {
      'id': movementId,
      'product_id': productId,
      'movement_type': stockMovementTypeValue(type),
      'quantity_delta_milli': quantityDeltaMilli,
      'reason': reason?.trim(),
      'source_entity_type': sourceEntityType,
      'source_entity_id': sourceEntityId,
      'occurred_at': now.toIso8601String(),
      'idempotency_key': idempotencyKey,
    });
    await executor.insert('sync_outbox', {
      'id': _uuid.v4(),
      'entity_type': 'stock_movement',
      'entity_id': movementId,
      'organization_id': context.organizationId,
      'business_id': context.businessId,
      'store_id': context.storeId,
      'terminal_id': context.terminalId,
      'idempotency_key': idempotencyKey,
      'payload_json': jsonEncode({
        'movementId': movementId,
        'productId': productId,
        'movementType': stockMovementTypeValue(type),
        'quantityDeltaMilli': quantityDeltaMilli,
        'reason': reason?.trim(),
        'sourceEntityType': sourceEntityType,
        'sourceEntityId': sourceEntityId,
        'occurredAt': now.toIso8601String(),
      }),
      'state': 'pending',
      'created_at': now.toIso8601String(),
    });
    await _appendAuditEvent(
      executor,
      context: context,
      action: 'stock.movement',
      entityType: 'stock_movement',
      entityId: movementId,
      occurredAt: now,
      metadata: {
        'productId': productId,
        'movementType': stockMovementTypeValue(type),
        'quantityDeltaMilli': quantityDeltaMilli,
      },
    );
    return movementId;
  }

  Future<String> recordStockMovement({
    required LocalSaleContext context,
    required String productId,
    required StockMovementType type,
    required int quantityDeltaMilli,
    String? reason,
  }) {
    return _database.transaction(
      (txn) => _insertStockMovement(
        txn,
        context: context,
        productId: productId,
        type: type,
        quantityDeltaMilli: quantityDeltaMilli,
        reason: reason,
      ),
    );
  }

  Future<String?> countStock({
    required LocalSaleContext context,
    required String productId,
    required int countedMilli,
    required String reason,
  }) {
    if (countedMilli < 0) {
      throw ArgumentError('Counted stock cannot be negative');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reason is required');
    }

    return _database.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity_delta_milli), 0) AS on_hand_milli
        FROM stock_movement
        WHERE product_id = ?
        ''',
        [productId],
      );
      final current = rows.single['on_hand_milli']! as int;
      final delta = countAdjustmentDelta(
        currentOnHandMilli: current,
        countedMilli: countedMilli,
      );
      if (delta == 0) {
        return null;
      }
      return _insertStockMovement(
        txn,
        context: context,
        productId: productId,
        type: StockMovementType.adjustment,
        quantityDeltaMilli: delta,
        reason: reason,
      );
    });
  }

  Future<OfflineSaleResult> finalizeCashSale({
    required LocalSaleContext context,
    required List<SaleLineInput> lines,
    required int tenderedMinor,
    String? customerId,
  }) {
    return _finalizeSale(
      context: context,
      lines: lines,
      paymentMethod: 'cash',
      tenderedMinor: tenderedMinor,
      customerId: customerId,
    );
  }

  Future<OfflineSaleResult> finalizeCustomerCreditSale({
    required LocalSaleContext context,
    required List<SaleLineInput> lines,
    required String customerId,
    DateTime? dueDate,
  }) {
    return _finalizeSale(
      context: context,
      lines: lines,
      paymentMethod: 'customer_credit',
      customerId: customerId,
      dueDate: dueDate,
    );
  }

  Future<OfflineSaleResult> _finalizeSale({
    required LocalSaleContext context,
    required List<SaleLineInput> lines,
    required String paymentMethod,
    int? tenderedMinor,
    String? customerId,
    DateTime? dueDate,
  }) async {
    final totals = priceSale(lines, context.taxMode);
    final isCash = paymentMethod == 'cash';
    final isCredit = paymentMethod == 'customer_credit';
    if (!isCash && !isCredit) {
      throw ArgumentError('Unsupported local payment method');
    }
    if (isCredit && customerId == null) {
      throw ArgumentError('Customer is required for Pay Later');
    }

    final tendered = isCash ? tenderedMinor : 0;
    if (isCash && tendered == null) {
      throw ArgumentError('Cash tender is required');
    }
    final changeMinor =
        isCash ? cashChangeDue(totals.totalMinor, tendered!) : 0;

    final saleId = _uuid.v4();
    final now = DateTime.now().toUtc();
    late final String invoiceNumber;
    var loyaltyPointsEarned = 0;
    var loyaltyPointsRedeemed = 0;
    var loyaltyRedeemedMinor = 0;

    await _database.transaction((txn) async {
      if (isCredit) {
        final customers = await txn.query(
          'customer',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customers.isEmpty) {
          throw StateError('Customer not found');
        }
      }

      final employeeRows = await txn.query(
        'employee',
        columns: ['role'],
        where: 'id = ? AND active = 1',
        whereArgs: [context.userId],
        limit: 1,
      );
      if (employeeRows.isEmpty) {
        throw StateError('Active cashier identity not found');
      }
      final actorRole = employeeRows.single['role']! as String;
      for (final input in lines) {
        final grossMinor =
            (input.product.unitPriceMinor * input.quantityMilli + 500) ~/ 1000;
        if (discountRequiresApproval(
          lineGrossMinor: grossMinor,
          discountMinor: input.discountMinor,
          actorRole: actorRole,
        )) {
          throw StateError('Manager approval is required for this discount');
        }
      }

      final sequenceRows = await txn.query(
        'terminal_sequence',
        columns: ['next_invoice'],
        where: 'terminal_code = ?',
        whereArgs: [context.terminalCode],
        limit: 1,
      );
      if (sequenceRows.isEmpty) {
        throw StateError('Terminal invoice sequence is missing');
      }
      final nextInvoice = sequenceRows.single['next_invoice']! as int;
      invoiceNumber =
          '${context.terminalCode}-${nextInvoice.toString().padLeft(6, '0')}';
      await txn.update(
        'terminal_sequence',
        {'next_invoice': nextInvoice + 1},
        where: 'terminal_code = ?',
        whereArgs: [context.terminalCode],
      );

      final shiftId = await _openShiftId(txn);
      await txn.insert('sale', {
        'id': saleId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'cashier_user_id': context.userId,
        'customer_id': customerId,
        'shift_id': shiftId,
        'invoice_number': invoiceNumber,
        'local_created_at': now.toIso8601String(),
        'subtotal_minor': totals.subtotalMinor,
        'discount_minor': totals.discountMinor,
        'tax_minor': totals.taxMinor,
        'total_minor': totals.totalMinor,
        'status': 'finalized',
      });

      for (final line in totals.lines) {
        await txn.insert('sale_line', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'product_id': line.product.id,
          'product_name_snapshot': line.product.name,
          'quantity_milli': line.quantityMilli,
          'unit_price_minor': line.product.unitPriceMinor,
          'gross_minor': line.grossMinor,
          'discount_minor': line.discountMinor,
          'discount_source': line.discountSource ??
              (line.discountMinor > 0 ? 'manual' : null),
          'discount_reference_id': line.discountReferenceId,
          'taxable_minor': line.taxableMinor,
          'cgst_minor': line.cgstMinor,
          'sgst_minor': line.sgstMinor,
          'igst_minor': line.igstMinor,
          'tax_minor': line.taxMinor,
          'total_minor': line.totalMinor,
          'tax_rate_bps_snapshot': line.product.taxRateBps,
          'tax_price_mode_snapshot':
              line.product.taxPriceMode == TaxPriceMode.exclusive
                  ? 'exclusive'
                  : 'inclusive',
          'tax_classification_type_snapshot':
              line.product.taxClassificationType == null
                  ? null
                  : taxClassificationTypeValue(
                      line.product.taxClassificationType!,
                    ),
          'tax_classification_code_snapshot':
              line.product.taxClassificationCode,
          'tax_rule_version_id_snapshot': line.product.taxRuleVersionId,
        });
        await txn.insert('stock_movement', {
          'id': _uuid.v4(),
          'product_id': line.product.id,
          'movement_type': 'sale',
          'quantity_delta_milli': -line.quantityMilli,
          'source_entity_type': 'sale',
          'source_entity_id': saleId,
          'occurred_at': now.toIso8601String(),
          'idempotency_key': 'sale:$saleId:${line.product.id}',
        });
      }

      final paymentId = _uuid.v4();
      await txn.insert('payment', {
        'id': paymentId,
        'sale_id': saleId,
        'method': paymentMethod,
        'amount_minor': totals.totalMinor,
        'tendered_minor': tendered ?? 0,
        'change_minor': changeMinor,
        'status': 'captured',
        'reconciliation_status': 'not_applicable',
        'created_at': now.toIso8601String(),
      });
      await txn.insert('payment_event', {
        'id': _uuid.v4(),
        'payment_id': paymentId,
        'event_type': 'captured',
        'payment_status': 'captured',
        'amount_minor': totals.totalMinor,
        'occurred_at': now.toIso8601String(),
        'metadata_json': jsonEncode({'method': paymentMethod}),
      });

      if (isCredit) {
        await txn.insert('customer_credit_entry', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'entry_type': 'charge',
          'amount_minor': totals.totalMinor,
          'sale_id': saleId,
          'due_date': dueDate?.toIso8601String().split('T').first,
          'occurred_at': now.toIso8601String(),
          'idempotency_key': 'credit:$saleId',
        });
      }

      final loyaltyDiscountLines = totals.lines.where(
        (line) => line.discountSource == 'loyalty' && line.discountMinor > 0,
      );
      for (final line in loyaltyDiscountLines) {
        loyaltyRedeemedMinor += line.discountMinor;
        if (line.discountReferenceId != customerId) {
          throw StateError('Loyalty discount customer does not match sale');
        }
        if (line.product.taxPriceMode != TaxPriceMode.inclusive) {
          throw StateError(
            'Loyalty redemption currently requires tax-inclusive products',
          );
        }
      }

      LoyaltyProgram? activeProgram;
      if (customerId != null) {
        final programRows = await txn.query(
          'loyalty_program',
          where: 'singleton_id = 1',
          limit: 1,
        );
        if (programRows.isNotEmpty) {
          final programRow = programRows.single;
          activeProgram = LoyaltyProgram(
            enabled: (programRow['enabled']! as int) == 1,
            pointsPer100Rupees:
                programRow['points_per_100_rupees']! as int,
            redemptionMinorPerPoint:
                programRow['redemption_minor_per_point']! as int,
            maxRedemptionBps:
                programRow['max_redemption_bps']! as int,
          );
        }
      }

      if (loyaltyRedeemedMinor > 0) {
        if (customerId == null || isCredit || activeProgram == null) {
          throw StateError('Loyalty redemption requires a cash customer sale');
        }
        validateLoyaltyProgram(activeProgram);
        if (!activeProgram.enabled) {
          throw StateError('Loyalty program is not enabled');
        }
        if (loyaltyRedeemedMinor % activeProgram.redemptionMinorPerPoint != 0) {
          throw StateError('Loyalty discount does not match point value');
        }
        loyaltyPointsRedeemed =
            loyaltyRedeemedMinor ~/ activeProgram.redemptionMinorPerPoint;

        final balanceRows = await txn.rawQuery(
          '''
          SELECT COALESCE(
            SUM(
              CASE
                WHEN entry_type IN ('earn', 'adjustment_in') THEN points
                ELSE -points
              END
            ),
            0
          ) AS points
          FROM customer_loyalty_entry
          WHERE customer_id = ?
          ''',
          [customerId],
        );
        final balance = balanceRows.single['points']! as int;
        final allowed = maxLoyaltyRedemption(
          saleMinor: totals.totalMinor + loyaltyRedeemedMinor,
          availablePoints: balance,
          requestedPoints: loyaltyPointsRedeemed,
          program: activeProgram,
        );
        if (allowed.points != loyaltyPointsRedeemed ||
            allowed.amountMinor != loyaltyRedeemedMinor) {
          throw StateError('Loyalty redemption exceeds available reward');
        }

        await txn.insert('customer_loyalty_entry', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'entry_type': 'redeem',
          'points': loyaltyPointsRedeemed,
          'sale_id': saleId,
          'note': 'Points redeemed on $invoiceNumber',
          'occurred_at': now.toIso8601String(),
          'idempotency_key': 'loyalty-redeem:$saleId',
        });
      }

      if (customerId != null && !isCredit && activeProgram != null) {
        loyaltyPointsEarned =
            earnedLoyaltyPoints(totals.totalMinor, activeProgram);
        if (loyaltyPointsEarned > 0) {
          await txn.insert('customer_loyalty_entry', {
            'id': _uuid.v4(),
            'customer_id': customerId,
            'entry_type': 'earn',
            'points': loyaltyPointsEarned,
            'sale_id': saleId,
            'note': 'Points earned on $invoiceNumber',
            'occurred_at': now.toIso8601String(),
            'idempotency_key': 'loyalty-earn:$saleId',
          });
        }
      }

      if (customerId != null &&
          (loyaltyPointsEarned > 0 || loyaltyPointsRedeemed > 0)) {
        await txn.insert('sale_loyalty', {
          'sale_id': saleId,
          'customer_id': customerId,
          'points_earned': loyaltyPointsEarned,
          'points_redeemed': loyaltyPointsRedeemed,
          'redeemed_minor': loyaltyRedeemedMinor,
        });
      }

      final promotionDiscounts = <String, int>{};
      for (final line in totals.lines) {
        if (line.discountSource == 'promotion' &&
            line.discountReferenceId != null &&
            line.discountMinor > 0) {
          promotionDiscounts.update(
            line.discountReferenceId!,
            (value) => value + line.discountMinor,
            ifAbsent: () => line.discountMinor,
          );
        }
      }
      for (final entry in promotionDiscounts.entries) {
        await txn.insert('promotion_redemption', {
          'id': _uuid.v4(),
          'promotion_id': entry.key,
          'customer_id': customerId,
          'sale_id': saleId,
          'discount_minor': entry.value,
          'redeemed_at': now.toIso8601String(),
          'idempotency_key': 'promotion:$saleId:${entry.key}',
        });
      }

      final idempotencyKey = _uuid.v4();
      await txn.insert('sync_outbox', {
        'id': _uuid.v4(),
        'entity_type': 'sale',
        'entity_id': saleId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'idempotency_key': idempotencyKey,
        'payload_json': jsonEncode({
          'saleId': saleId,
          'customerId': customerId,
          'invoiceNumber': invoiceNumber,
          'createdAt': now.toIso8601String(),
          'subtotalMinor': totals.subtotalMinor,
          'discountMinor': totals.discountMinor,
          'loyaltyPointsRedeemed': loyaltyPointsRedeemed,
          'loyaltyRedeemedMinor': loyaltyRedeemedMinor,
          'loyaltyPointsEarned': loyaltyPointsEarned,
          'taxMinor': totals.taxMinor,
          'totalMinor': totals.totalMinor,
          'payment': {
            'method': paymentMethod,
            'amountMinor': totals.totalMinor,
            'tenderedMinor': tendered ?? 0,
            'changeMinor': changeMinor,
          },
          'creditDueDate': dueDate?.toIso8601String().split('T').first,
          'lines': totals.lines
              .map(
                (line) => {
                  'productId': line.product.id,
                  'name': line.product.name,
                  'quantityMilli': line.quantityMilli,
                  'unitPriceMinor': line.product.unitPriceMinor,
                  'discountMinor': line.discountMinor,
                  'discountSource': line.discountSource ??
                      (line.discountMinor > 0 ? 'manual' : null),
                  'discountReferenceId': line.discountReferenceId,
                  'taxMinor': line.taxMinor,
                  'totalMinor': line.totalMinor,
                },
              )
              .toList(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
      await _appendAuditEvent(
        txn,
        context: context,
        action: 'sale.finalized',
        entityType: 'sale',
        entityId: saleId,
        occurredAt: now,
        metadata: {'reference': invoiceNumber, 'paymentMethod': paymentMethod, 'totalMinor': totals.totalMinor},
      );
    });

    final receipt = StringBuffer()
      ..writeln(context.businessName)
      ..writeln(context.storeName)
      ..writeln('Bill $invoiceNumber')
      ..writeln('------------------------');
    for (final line in totals.lines) {
      receipt.writeln(
        '${line.product.name}  ${line.quantityMilli / 1000}  ${formatInr(line.totalMinor)}',
      );
    }
    receipt
      ..writeln('------------------------')
      ..writeln('Total  ${formatInr(totals.totalMinor)}');

    if (loyaltyPointsRedeemed > 0) {
      receipt.writeln(
        'Loyalty -$loyaltyPointsRedeemed points '
        '(${formatInr(loyaltyRedeemedMinor)} off)',
      );
    }
    if (loyaltyPointsEarned > 0) {
      receipt.writeln('Loyalty +$loyaltyPointsEarned points earned');
    }

    if (isCash) {
      receipt
        ..writeln('Cash   ${formatInr(tendered!)}')
        ..writeln('Return ${formatInr(changeMinor)}');
    } else {
      receipt.writeln('Customer Credit  ${formatInr(totals.totalMinor)}');
      if (dueDate != null) {
        receipt.writeln(
          'Due ${dueDate.toIso8601String().split('T').first}',
        );
      }
    }

    return OfflineSaleResult(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      totalMinor: totals.totalMinor,
      tenderedMinor: tendered ?? 0,
      changeMinor: changeMinor,
      receiptText: receipt.toString(),
      loyaltyPointsEarned: loyaltyPointsEarned,
    );
  }
}
