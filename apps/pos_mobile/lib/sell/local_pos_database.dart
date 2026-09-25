import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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
        version: 2,
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
              active INTEGER NOT NULL DEFAULT 1,
              UNIQUE (barcode)
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
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        unitPriceMinor < 0 ||
        taxRateBps < 0 ||
        taxRateBps > 10000) {
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
      'active': 1,
    });
    return product;
  }

  Future<int> pendingOutboxCount() async {
    final rows = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_outbox WHERE state = 'pending'",
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  Future<OfflineSaleResult> finalizeCashSale({
    required LocalSaleContext context,
    required List<SaleLineInput> lines,
    required int tenderedMinor,
  }) async {
    final totals = priceSale(lines, context.taxMode);
    final changeMinor = cashChangeDue(totals.totalMinor, tenderedMinor);
    final saleId = _uuid.v4();
    final now = DateTime.now().toUtc();
    late final String invoiceNumber;

    await _database.transaction((txn) async {
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
      }

      final paymentId = _uuid.v4();
      await txn.insert('payment', {
        'id': paymentId,
        'sale_id': saleId,
        'method': 'cash',
        'amount_minor': totals.totalMinor,
        'tendered_minor': tenderedMinor,
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
        'metadata_json': jsonEncode({'method': 'cash'}),
      });

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
          'invoiceNumber': invoiceNumber,
          'createdAt': now.toIso8601String(),
          'subtotalMinor': totals.subtotalMinor,
          'discountMinor': totals.discountMinor,
          'taxMinor': totals.taxMinor,
          'totalMinor': totals.totalMinor,
          'payment': {
            'method': 'cash',
            'amountMinor': totals.totalMinor,
            'tenderedMinor': tenderedMinor,
            'changeMinor': changeMinor,
          },
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
      ..writeln('Total  ${formatInr(totals.totalMinor)}')
      ..writeln('Cash   ${formatInr(tenderedMinor)}')
      ..writeln('Return ${formatInr(changeMinor)}');

    return OfflineSaleResult(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      totalMinor: totals.totalMinor,
      tenderedMinor: tenderedMinor,
      changeMinor: changeMinor,
      receiptText: receipt.toString(),
    );
  }
}
