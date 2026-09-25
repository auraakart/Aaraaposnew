import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../customers/customer_domain.dart';
import '../inventory/inventory_domain.dart';
import '../operations/operations_domain.dart';
import '../purchases/purchase_domain.dart';
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
}

class OfflineSaleResult {
  const OfflineSaleResult({
    required this.saleId,
    required this.invoiceNumber,
    required this.totalMinor,
    required this.tenderedMinor,
    required this.changeMinor,
    required this.receiptText,
  });

  final String saleId;
  final String invoiceNumber;
  final int totalMinor;
  final int tenderedMinor;
  final int changeMinor;
  final String receiptText;
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
        version: 6,
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
              tax_mode TEXT NOT NULL
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
              taxable_minor INTEGER NOT NULL,
              cgst_minor INTEGER NOT NULL,
              sgst_minor INTEGER NOT NULL,
              igst_minor INTEGER NOT NULL,
              tax_minor INTEGER NOT NULL,
              total_minor INTEGER NOT NULL
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
              reason TEXT
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
              state TEXT NOT NULL,
              created_at TEXT NOT NULL,
              last_error TEXT
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
      await txn.insert('employee', {
        'id': context.userId,
        'name': 'Owner',
        'role': 'owner',
        'active': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    return context;
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
    int reorderLevelMilli = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        unitPriceMinor < 0 ||
        taxRateBps < 0 ||
        taxRateBps > 10000 ||
        reorderLevelMilli < 0) {
      throw ArgumentError('Invalid product');
    }
    final product = Product(
      id: _uuid.v4(),
      name: trimmed,
      barcode: barcode?.trim().isEmpty ?? true ? null : barcode!.trim(),
      unitPriceMinor: unitPriceMinor,
      taxRateBps: taxRateBps,
      taxPriceMode: taxPriceMode,
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
      'reorder_level_milli': reorderLevelMilli,
      'active': 1,
    });
    return product;
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
      await txn.insert('customer_credit_entry', {
        'id': entryId,
        'customer_id': customerId,
        'entry_type': 'payment',
        'amount_minor': amountMinor,
        'collection_method': collectionMethod,
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

  Future<int> pendingOutboxCount() async {
    final rows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_outbox WHERE state = 'pending'",
    );
    return (rows.single['count'] as int?) ?? 0;
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

      await txn.insert('sale', {
        'id': saleId,
        'organization_id': context.organizationId,
        'business_id': context.businessId,
        'store_id': context.storeId,
        'terminal_id': context.terminalId,
        'cashier_user_id': context.userId,
        'customer_id': customerId,
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
          'taxable_minor': line.taxableMinor,
          'cgst_minor': line.cgstMinor,
          'sgst_minor': line.sgstMinor,
          'igst_minor': line.igstMinor,
          'tax_minor': line.taxMinor,
          'total_minor': line.totalMinor,
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
                  'taxMinor': line.taxMinor,
                  'totalMinor': line.totalMinor,
                },
              )
              .toList(),
        }),
        'state': 'pending',
        'created_at': now.toIso8601String(),
      });
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
    );
  }
}
