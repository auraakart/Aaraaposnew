import 'package:aaraapos_pos/loyalty/loyalty_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('loyalty earn redeem and full return restore original balance', () async {
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
    await database.updateLoyaltyProgram(
      context: context,
      program: const LoyaltyProgram(
        enabled: true,
        pointsPer100Rupees: 2,
        redemptionMinorPerPoint: 100,
        maxRedemptionBps: 2000,
      ),
    );

    final customer = await database.addCustomer(name: 'Ramesh');
    final product = await database.addProduct(
      name: 'Groceries',
      unitPriceMinor: 125000,
    );

    final first = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 125000,
      customerId: customer.id,
    );

    expect(first.loyaltyPointsEarned, 25);
    expect(await database.customerLoyaltyBalance(customer.id), 25);

    final redemptionProduct = await database.addProduct(
      name: 'Reward item',
      unitPriceMinor: 10000,
    );
    final second = await database.finalizeCashSale(
      context: context,
      lines: [
        SaleLineInput(
          product: redemptionProduct,
          quantityMilli: 1000,
          discountMinor: 2000,
          discountSource: 'loyalty',
          discountReferenceId: customer.id,
        ),
      ],
      tenderedMinor: 8000,
      customerId: customer.id,
    );

    expect(second.loyaltyPointsEarned, 1);
    expect(await database.customerLoyaltyBalance(customer.id), 6);

    final returnable = (await database.listReturnableSales())
        .firstWhere((sale) => sale.saleId == second.saleId);
    await database.processReturn(
      context: context,
      saleId: second.saleId,
      requests: [
        ReturnLineRequest(
          saleLineId: returnable.lines.single.saleLineId,
          quantityMilli: 1000,
        ),
      ],
      reason: 'Full return',
    );

    expect(await database.customerLoyaltyBalance(customer.id), 25);
    expect(await database.loyaltyEntryCountForCustomer(customer.id), 5);
  });

  test('Pay Later sale does not award loyalty before settlement', () async {
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
    await database.updateLoyaltyProgram(
      context: context,
      program: const LoyaltyProgram(
        enabled: true,
        pointsPer100Rupees: 2,
        redemptionMinorPerPoint: 100,
        maxRedemptionBps: 2000,
      ),
    );
    final customer = await database.addCustomer(name: 'Anita');
    final product = await database.addProduct(
      name: 'Credit item',
      unitPriceMinor: 10000,
    );

    final result = await database.finalizeCustomerCreditSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      customerId: customer.id,
    );

    expect(result.loyaltyPointsEarned, 0);
    expect(await database.customerLoyaltyBalance(customer.id), 0);
  });

  test('promotion redemption is traceable to the finalized sale', () async {
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
      name: 'Milk',
      unitPriceMinor: 10000,
    );
    final promotion = await database.addPromotion(
      context: context,
      name: 'Milk ₹20 off',
      type: 'fixed',
      value: 2000,
      startsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      endsAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      productIds: [product.id],
    );

    final evaluation = await database.bestPromotionForLines([
      SaleLineInput(product: product, quantityMilli: 1000),
    ]);
    expect(evaluation?.promotion.id, promotion.id);
    expect(evaluation?.discountMinor, 2000);

    final sale = await database.finalizeCashSale(
      context: context,
      lines: [
        SaleLineInput(
          product: product,
          quantityMilli: 1000,
          discountMinor: 2000,
          discountSource: 'promotion',
          discountReferenceId: promotion.id,
        ),
      ],
      tenderedMinor: 8000,
    );

    expect(await database.promotionRedemptionCountForSale(sale.saleId), 1);
  });
}
