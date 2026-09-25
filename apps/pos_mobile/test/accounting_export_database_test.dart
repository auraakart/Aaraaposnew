import 'package:aaraapos_pos/accounting/accounting_domain.dart';
import 'package:aaraapos_pos/intelligence/owner_intelligence.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('export links sale return purchase expense and supplier ledger', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final context = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );
    final product = await database.addProduct(
      name: 'Taxed item',
      unitPriceMinor: 11800,
      taxRateBps: 1800,
      taxPriceMode: TaxPriceMode.inclusive,
    );
    final supplier = await database.addSupplier(
      name: 'Distributor',
      mobile: '+919999999999',
    );

    final order = await database.createPurchaseOrder(
      context: context,
      supplierId: supplier.id,
      productId: product.id,
      quantityMilli: 1000,
      unitCostMinor: 6000,
      taxMinor: 1080,
    );
    await database.receivePurchaseOrder(
      context: context,
      purchaseOrderId: order,
      supplierInvoiceNumber: 'SUP-1',
    );

    final sale = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 11800,
    );
    await database.addExpense(
      context: context,
      category: 'Transport',
      amountMinor: 500,
      paymentMethod: 'upi',
    );

    final returnable = (await database.listReturnableSales())
        .firstWhere((item) => item.saleId == sale.saleId);
    await database.processReturn(
      context: context,
      saleId: sale.saleId,
      requests: [
        ReturnLineRequest(
          saleLineId: returnable.lines.single.saleLineId,
          quantityMilli: 1000,
        ),
      ],
      reason: 'Customer return',
    );

    final rows = await database.accountingExportRows(ReportPeriod.today);
    final kinds = rows.map((row) => row.kind).toSet();

    expect(kinds, contains(AccountingRegisterKind.sales));
    expect(kinds, contains(AccountingRegisterKind.returns));
    expect(kinds, contains(AccountingRegisterKind.purchases));
    expect(kinds, contains(AccountingRegisterKind.expenses));
    expect(kinds, contains(AccountingRegisterKind.supplierLedger));

    final sales = rows.singleWhere(
      (row) => row.kind == AccountingRegisterKind.sales,
    );
    expect(sales.sourceId, sale.saleId);
    expect(sales.tax.taxableMinor, 10000);
    expect(sales.tax.cgstMinor, 900);
    expect(sales.tax.sgstMinor, 900);

    final purchase = rows.singleWhere(
      (row) => row.kind == AccountingRegisterKind.purchases,
    );
    expect(purchase.documentNumber, 'SUP-1');
    expect(purchase.tax.taxableMinor, 6000);
    expect(purchase.tax.unclassifiedTaxMinor, 1080);

    final manifest = buildAccountingManifest(rows);
    expect(manifest.salesMinor, 11800);
    expect(manifest.returnsMinor, 11800);
    expect(manifest.netSalesMinor, 0);
    expect(manifest.outputCgstAfterReturnsMinor, 0);
    expect(manifest.purchaseUnclassifiedTaxMinor, 1080);
    expect(manifest.expensesMinor, 500);
  });
}
